#include "app_paths.hpp"

#include <windows.h>

#include <KnownFolders.h>
#include <ShlObj.h>

#include <stdexcept>

namespace spellbook::app
{

std::filesystem::path default_data_dir()
{
    PWSTR raw = nullptr;
    const HRESULT hr = SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_CREATE, nullptr, &raw);
    if (FAILED(hr))
    {
        CoTaskMemFree(raw);
        throw std::runtime_error(
            "Windows could not locate the Local AppData folder (SHGetKnownFolderPath failed)");
    }
    std::filesystem::path root{raw};
    CoTaskMemFree(raw);
    return root / L"Spellbook";
}

std::filesystem::path database_path(const std::filesystem::path& data_dir)
{
    return data_dir / L"spellbook.db";
}

std::filesystem::path log_dir(const std::filesystem::path& data_dir)
{
    return data_dir / L"logs";
}

}  // namespace spellbook::app
