/* Test-only Wayland virtual pointer. Never invoked against the user's display. */
#include <wayland-client.h>
#include "virtual-pointer.h"
#include <linux/input-event-codes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(interface, zwlr_virtual_pointer_manager_v1_interface.name))
        manager=wl_registry_bind(registry,name,&zwlr_virtual_pointer_manager_v1_interface,1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {(void)data;(void)registry;(void)name;}
static const struct wl_registry_listener listener={global,removed};
static uint32_t timestamp(void) {struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return (uint32_t)(t.tv_sec*1000+t.tv_nsec/1000000);}
int main(int argc,char **argv) {
    if(argc!=5 || !getenv("SHITTIM_TEST_SESSION"))return 2;
    struct wl_display *display=wl_display_connect(NULL);
    if(!display)return 3;
    struct wl_registry *registry=wl_display_get_registry(display);
    wl_registry_add_listener(registry,&listener,NULL);wl_display_roundtrip(display);
    if(!manager){fprintf(stderr,"virtual pointer protocol unavailable\n");return 4;}
    struct zwlr_virtual_pointer_v1 *pointer=zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager,NULL);
    zwlr_virtual_pointer_v1_motion_absolute(pointer,timestamp(),atoi(argv[1]),atoi(argv[2]),atoi(argv[3]),atoi(argv[4]));
    zwlr_virtual_pointer_v1_frame(pointer);wl_display_roundtrip(display);usleep(15000);
    zwlr_virtual_pointer_v1_button(pointer,timestamp(),BTN_LEFT,WL_POINTER_BUTTON_STATE_PRESSED);
    zwlr_virtual_pointer_v1_frame(pointer);wl_display_roundtrip(display);usleep(15000);
    zwlr_virtual_pointer_v1_button(pointer,timestamp(),BTN_LEFT,WL_POINTER_BUTTON_STATE_RELEASED);
    zwlr_virtual_pointer_v1_frame(pointer);wl_display_roundtrip(display);
    zwlr_virtual_pointer_v1_destroy(pointer);zwlr_virtual_pointer_manager_v1_destroy(manager);
    wl_registry_destroy(registry);wl_display_disconnect(display);return 0;
}
