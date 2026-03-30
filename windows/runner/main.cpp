#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.

  HANDLE hMutex = CreateMutex(NULL, TRUE, L"AnfibiusConnect_Unique_Mutex_Lock");
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    // Buscar la ventana de la instancia que ya está abierta por su título
    HWND hwnd = FindWindow(NULL, L"Anfibius Connect");
    
    if (hwnd) {
      // Si la ventana está minimizada (en la barra de tareas), la restaura
      if (IsIconic(hwnd)) {
        ShowWindow(hwnd, SW_RESTORE);
      }
      // Fuerza a la ventana a saltar al primer plano
      SetForegroundWindow(hwnd);
    }
    
    // Cierra el hilo de esta segunda instancia silenciosamente
    CloseHandle(hMutex);
    return EXIT_SUCCESS; 
  }

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Anfibius Connect", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true); 

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}