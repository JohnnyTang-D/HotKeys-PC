; ============================================================
; CapsLock 导航模式
; 开启大写后，WASD 模拟方向键，附加编辑快捷键
; Esc 退出大写模式
; ============================================================

#HotIf (isCapsLockNavEnabled && GetKeyState('Capslock', 'T'))

; --- 方向键映射 ---
w::Up
a::Left
s::Down
d::Right

; --- 编辑键映射 ---
e::BackSpace
q::Del
f::Home
j::End

; --- 退出大写模式 ---
Esc:: SetCapsLockState('Off')

#HotIf
