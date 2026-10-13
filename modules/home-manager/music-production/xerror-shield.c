/*
 * xerror_shield.c — LD_PRELOAD shim that replaces any X error handler with a
 * lenient one (log + return 0), so a BadAtom/BadMatch from a plugin's X11
 * probe (e.g. Vital's JUCE Desktop() querying the missing _NET_WORKAREA atom
 * under niri/XWayland) does NOT hit Ardour's fatal gdk_x_error -> exit().
 *
 * Build: gcc -shared -fPIC -o xerror_shield.so xerror_shield.c -lX11 -ldl
 * Use:   LD_PRELOAD=/path/xerror_shield.so ardour9
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <dlfcn.h>
#include <X11/Xlib.h>

static int safe_x_error_handler (Display* dpy, XErrorEvent* ev)
{
    char buf[256] = { 0 };
    XGetErrorText (dpy, ev->error_code, buf, sizeof buf);
    fprintf (stderr, "[xerror-shield] X error suppressed: %s (request code %d, serial %lu)\n",
             buf, ev->request_code, ev->serial);
    return 0;
}

static int safe_xio_error_handler (Display* dpy)
{
    fprintf (stderr, "[xerror-shield] X IO error suppressed\n");
    return 0;
}

XErrorHandler XSetErrorHandler (XErrorHandler handler)
{
    static XErrorHandler (*real) (XErrorHandler) = 0;
    if (!real)
        real = dlsym (RTLD_NEXT, "XSetErrorHandler");
    (void) handler;
    return real (safe_x_error_handler);
}

XIOErrorHandler XSetIOErrorHandler (XIOErrorHandler handler)
{
    static XIOErrorHandler (*real) (XIOErrorHandler) = 0;
    if (!real)
        real = dlsym (RTLD_NEXT, "XSetIOErrorHandler");
    (void) handler;
    return real (safe_xio_error_handler);
}