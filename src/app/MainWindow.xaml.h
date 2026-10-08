#pragma once

#include <winrt/Microsoft.UI.Xaml.Media.h>

#include "MainWindow.g.h"

namespace winrt::Spellbook::implementation
{
struct MainWindow : MainWindowT<MainWindow>
{
    MainWindow() = default;
    void initialize(bool smoke);

private:
    Microsoft::UI::Xaml::Media::CompositionTarget::Rendering_revoker rendering_;
};
}  // namespace winrt::Spellbook::implementation

namespace winrt::Spellbook::factory_implementation
{
struct MainWindow : MainWindowT<MainWindow, implementation::MainWindow>
{
};
}  // namespace winrt::Spellbook::factory_implementation
