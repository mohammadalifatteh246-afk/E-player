#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr ULONG_PTR kExternalLaunchCopyDataTag = 0x45504C59;  // 'EPLY'

bool HasUriSchemeOrFlag(const std::string& arg) {
  if (arg.empty() || arg[0] == '-') {
    return true;
  }
  return arg.find("://") != std::string::npos;
}

std::vector<std::string> ResolveCliPaths(const std::vector<std::string>& args) {
  std::vector<std::string> resolved;
  resolved.reserve(args.size());
  for (const auto& arg : args) {
    if (HasUriSchemeOrFlag(arg)) {
      resolved.push_back(arg);
      continue;
    }
    int wide_len = ::MultiByteToWideChar(
        CP_UTF8, 0, arg.c_str(), static_cast<int>(arg.size()), nullptr, 0);
    if (wide_len <= 0) {
      resolved.push_back(arg);
      continue;
    }
    std::wstring wide_in(wide_len, L'\0');
    ::MultiByteToWideChar(CP_UTF8, 0, arg.c_str(),
                          static_cast<int>(arg.size()), wide_in.data(),
                          wide_len);

    DWORD needed = ::GetFullPathNameW(wide_in.c_str(), 0, nullptr, nullptr);
    if (needed == 0) {
      resolved.push_back(arg);
      continue;
    }
    std::wstring wide_out(needed, L'\0');
    DWORD written = ::GetFullPathNameW(wide_in.c_str(), needed,
                                       wide_out.data(), nullptr);
    if (written == 0) {
      resolved.push_back(arg);
      continue;
    }
    wide_out.resize(written);
    std::string utf8_out = Utf8FromUtf16(wide_out.c_str());
    resolved.push_back(utf8_out.empty() ? arg : utf8_out);
  }
  return resolved;
}

bool IsSingleInstanceModeEnabled(const std::vector<std::string>& args) {
  for (const auto& arg : args) {
    if (arg == "--allow-multiple") {
      return false;
    }
  }

  DWORD value = 1;
  DWORD data_size = sizeof(value);
  LSTATUS status = ::RegGetValueW(
      HKEY_CURRENT_USER, L"Software\\E-Player", L"SingleInstance",
      RRF_RT_REG_DWORD, nullptr, &value, &data_size);
  if (status == ERROR_SUCCESS && value == 0) {
    return false;
  }
  return true;
}

bool ForwardLaunchToExistingInstance(const std::vector<std::string>& args) {
  HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"E-Player");
  if (existing == nullptr) {
    return false;
  }

  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  }
  ::SetForegroundWindow(existing);

  std::string joined;
  for (size_t i = 0; i < args.size(); ++i) {
    if (i > 0) {
      joined.push_back('\n');
    }
    joined.append(args[i]);
  }

  if (!joined.empty()) {
    COPYDATASTRUCT cds{};
    cds.dwData = kExternalLaunchCopyDataTag;
    cds.cbData = static_cast<DWORD>(joined.size());
    cds.lpData = const_cast<char*>(joined.data());
    ::SendMessageW(existing, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds));
  }

  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::vector<std::string> command_line_arguments =
      ResolveCliPaths(GetCommandLineArguments());

  if (IsSingleInstanceModeEnabled(command_line_arguments) &&
      ForwardLaunchToExistingInstance(command_line_arguments)) {
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"E-Player", origin, size)) {
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
