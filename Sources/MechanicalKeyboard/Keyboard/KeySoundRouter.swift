import Carbon.HIToolbox

enum SoundKind: String, CaseIterable, Sendable {
    case normal, space, enter, backspace
}

enum KeySoundRouter {
    static func kind(for keyCode: Int64, isRepeat: Bool) -> SoundKind? {
        guard !isRepeat, (0...127).contains(keyCode) else { return nil }
        switch keyCode {
        case Int64(kVK_Space): return .space
        case Int64(kVK_Return), Int64(kVK_ANSI_KeypadEnter): return .enter
        case Int64(kVK_Delete), Int64(kVK_ForwardDelete): return .backspace
        case Int64(kVK_Command), Int64(kVK_RightCommand),
             Int64(kVK_Shift), Int64(kVK_RightShift),
             Int64(kVK_Option), Int64(kVK_RightOption),
             Int64(kVK_Control), Int64(kVK_RightControl),
             Int64(kVK_CapsLock), Int64(kVK_Function),
             Int64(kVK_F1), Int64(kVK_F2), Int64(kVK_F3), Int64(kVK_F4),
             Int64(kVK_F5), Int64(kVK_F6), Int64(kVK_F7), Int64(kVK_F8),
             Int64(kVK_F9), Int64(kVK_F10), Int64(kVK_F11), Int64(kVK_F12),
             Int64(kVK_F13), Int64(kVK_F14), Int64(kVK_F15), Int64(kVK_F16),
             Int64(kVK_F17), Int64(kVK_F18), Int64(kVK_F19), Int64(kVK_F20),
             Int64(kVK_Help), Int64(kVK_Home), Int64(kVK_End),
             Int64(kVK_PageUp), Int64(kVK_PageDown),
             Int64(kVK_LeftArrow), Int64(kVK_RightArrow),
             Int64(kVK_UpArrow), Int64(kVK_DownArrow):
            return nil
        default: return .normal
        }
    }
}
