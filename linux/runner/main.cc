#include "my_application.h"

int main(int argc, char** argv) {
  // WebKitGTK 2.54 can fail to import DMA-BUF images on mixed GPU/Wayland.
  // Keep shared-memory transport available; honor explicit environment overrides.
  if (g_getenv("WEBKIT_DMABUF_RENDERER_FORCE_SHM") == nullptr &&
      g_getenv("WEBKIT_DISABLE_DMABUF_RENDERER") == nullptr) {
    g_setenv("WEBKIT_DMABUF_RENDERER_FORCE_SHM", "1", FALSE);
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
