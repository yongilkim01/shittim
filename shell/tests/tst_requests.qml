import QtQuick
import QtTest
import "../core"

TestCase {
    name:"RequestContracts"
    Component {id:ledgerFactory;RequestLedger {}}
    Component {id:consumersFactory;ConsumerSet {}}
    Component {id:leaseFactory;ServiceLease {}}
    Component {id:spyFactory;SignalSpy {}}
    function init(){failOnWarning(/.*/)}
    function test_timeout_terminates_busy_and_late_success_does_not_complete_new_request() {
        const ledger=createTemporaryObject(ledgerFactory,this)
        let now=100;ledger.now=function(){return now}
        const spy=createTemporaryObject(spyFactory,this,{target:ledger,signalName:"finished"})
        const first=ledger.begin("launch",10,"app"),second=ledger.begin("brightness",30,"device")
        now=111;ledger.expire();compare(spy.count,1);compare(spy.signalArguments[0][0].status,"timeout")
        verify(!ledger.complete(first,true,"",false));verify(ledger.busy)
        ledger.complete(second,true,"",false);verify(!ledger.busy);compare(spy.count,2)
    }
    function test_cancel_all_releases_every_request_with_stable_ids() {
        const ledger=createTemporaryObject(ledgerFactory,this)
        const spy=createTemporaryObject(spyFactory,this,{target:ledger,signalName:"finished"})
        const first=ledger.begin("pair",1000,"device"),second=ledger.begin("profile",1000,"")
        ledger.cancelAll("BackendExited");compare(spy.count,2);verify(!ledger.busy)
        compare(spy.signalArguments[0][0].id,first);compare(spy.signalArguments[1][0].id,second)
        compare(spy.signalArguments[0][0].status,"cancelled")
    }
    function test_request_capacity_is_bounded() {
        const ledger=createTemporaryObject(ledgerFactory,this)
        for(let index=0;index<64;index++)verify(ledger.begin("fit",1000,"window")>0)
        compare(ledger.begin("fit",1000,"window"),0);ledger.cancelAll()
    }
    function test_timeout_callback_can_cancel_other_requests_without_invalidating_iteration(){
        const ledger=createTemporaryObject(ledgerFactory,this);let now=0;ledger.now=function(){return now}
        const spy=createTemporaryObject(spyFactory,this,{target:ledger,signalName:"finished"})
        ledger.begin("first",1,"");ledger.begin("second",1,"")
        ledger.finished.connect(function(result){if(result.operation==="first")ledger.cancelAll()})
        now=2;ledger.expire();compare(spy.count,2);verify(!ledger.busy)
    }
    function test_consumers_change_without_services_knowing_page_names() {
        const first=createTemporaryObject(consumersFactory,this),second=createTemporaryObject(consumersFactory,this)
        const lease=createTemporaryObject(leaseFactory,this,{service:first,active:true})
        verify(first.active);compare(first.consumers.length,1)
        lease.sync();compare(first.consumers.length,1)
        lease.service=second;verify(!first.active);verify(second.active)
        lease.active=false;verify(!second.active)
        lease.active=true;lease.destroy();wait(0);verify(!second.active)
    }
}
