-- System clipboard, when there is a provider: pbcopy on macOS, xclip/wl-copy or
-- (over ssh, nvim ≥ 0.10) OSC 52 on Linux. Without the check a headless box
-- prints "clipboard: No provider" at every start.
if vim.fn.has("clipboard") == 1 then
  vim.opt.clipboard = "unnamedplus"
end
vim.opt.mouse = ""
