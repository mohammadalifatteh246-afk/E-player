#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <sstream>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr ULONG_PTR kExternalLaunchCopyDataTag = 0x45504C59;  // 'EPLY'

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  external_launch_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.example.app/external_launch",
          &flutter::StandardMethodCodec::GetInstance());
  external_launch_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "getInitialLaunch") {
          result->Success();
        } else if (call.method_name() == "getPlatformCapabilities") {
          flutter::EncodableMap caps;
          caps[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          caps[flutter::EncodableValue("cliArgsSupported")] =
              flutter::EncodableValue(true);
          caps[flutter::EncodableValue("singleInstanceIpcSupported")] =
              flutter::EncodableValue(true);
          result->Success(flutter::EncodableValue(caps));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  external_launch_channel_.reset();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleExternalCopyData(const COPYDATASTRUCT* cds) {
  if (!external_launch_channel_ || cds->lpData == nullptr ||
      cds->cbData == 0) {
    return;
  }

  std::string raw(static_cast<const char*>(cds->lpData), cds->cbData);
  flutter::EncodableList args_list;
  std::stringstream ss(raw);
  std::string line;
  while (std::getline(ss, line, '\n')) {
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }
    if (!line.empty()) {
      args_list.push_back(flutter::EncodableValue(line));
    }
  }

  if (args_list.empty()) {
    return;
  }

  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("args")] = flutter::EncodableValue(args_list);
  payload[flutter::EncodableValue("source")] =
      flutter::EncodableValue("windows_single_instance");

  external_launch_channel_->InvokeMethod(
      "onExternalLaunch", std::make_unique<flutter::EncodableValue>(payload));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_COPYDATA: {
      const auto* cds = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      if (cds != nullptr && cds->dwData == kExternalLaunchCopyDataTag) {
        HandleExternalCopyData(cds);
        return TRUE;
      }
      break;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
