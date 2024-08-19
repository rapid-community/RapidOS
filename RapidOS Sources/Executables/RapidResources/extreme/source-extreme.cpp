#include <Windows.h>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    const char* message = "You are about to install an unstable version, which is RapidOS Extreme.\n\n"
                          "This is a heavily stripped-down version of Windows, designed primarily for gaming.\n\n"
                          "Please be aware that this version may encounter operational issues.\n\n"
                          "Many standard applications and functionalities may not work properly.\n\n"
                          "For the best experience, we recommend installing the Stable or Speed versions.\n\n"
                          "Thank you for your understanding and caution!";
    const char* title = "Attention!";

    MessageBoxA(NULL, message, title, MB_OK | MB_ICONWARNING | MB_SYSTEMMODAL);

    // Hide the console window
    HWND hwnd = GetConsoleWindow();
    ShowWindow(hwnd, SW_HIDE);

    return 0;
}
