import QtQuick
import QtTest
import "../ui/AssetPaths.js" as Assets
import "../components/launcher/IconResolver.js" as Icons
import "../components/dock"

TestCase {
    id: testCase
    name: "RepositoryAssets"; width: 800; height: 500; visible: true; when: windowShown
    readonly property string shellDirectory: decodeURIComponent(String(Qt.resolvedUrl(".."))).replace(/^file:\/\/\/([A-Za-z]:)/,"$1").replace(/^file:\/\//,"")
    Component { id: imageFactory; Image { width: 32; height: 32 } }
    Component { id: dockFactory; DockView { width: 720; height: 420 } }
    function init() { failOnWarning(/.*/) }
    function asset(relative) { return Assets.asset(shellDirectory,relative) }
    function icon(app) { return Icons.resolve(app,()=>"",name=>asset("icons/Shittim-HUD/scalable/apps/"+name+".svg"),name=>asset("icons/Shittim-HUD/scalable/places/"+name+".svg")) }
    function test_local_file_urls_escape_qml_interception_and_preserve_special_paths() {
        compare(Assets.fileUrl("/home/한글 # ? %/shell/../assets/icon.svg"),"file:///home/%ED%95%9C%EA%B8%80%20%23%20%3F%20%25/shell/../assets/icon.svg")
        compare(Assets.fileUrl("C:\\repo #\\assets\\icon.svg"),"file:///C:/repo%20%23/assets/icon.svg")
        compare(Assets.fileUrl("relative/path"),"")
    }
    function test_dock_and_desktop_use_real_loadable_repository_images() {
        const apps=[{id:"kitty.desktop",icons:["kitty"]},{id:"org.shittim.Files.desktop",icons:["system-file-manager"]}]
        const dock=createTemporaryObject(dockFactory,testCase,{apps:apps,iconSource:icon,assetSource:asset})
        for(const app of apps) tryCompare(findChild(dock,"dock-image-"+app.id),"status",Image.Ready)
        for(const utility of ["dock-settings","dock-trash"]) {
            const source=findChild(dock,utility).imageSource
            verify(source.indexOf("file:")===0)
            const image=createTemporaryObject(imageFactory,testCase,{source:source});tryCompare(image,"status",Image.Ready)
        }
        for(const entry of [{directory:true,icons:["user-home"]},{directory:true,icons:["folder-projects"]},{directory:true,icons:["user-trash"]}]) {
            const source=icon(entry),image=createTemporaryObject(imageFactory,testCase,{source:source})
            verify(source.indexOf("file:")===0);tryCompare(image,"status",Image.Ready)
        }
        const wallpaper=createTemporaryObject(imageFactory,testCase,{source:asset("wallpapers/shittim-lake.png")});tryCompare(wallpaper,"status",Image.Ready)
    }
}
