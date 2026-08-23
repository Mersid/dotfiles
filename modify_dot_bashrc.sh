chezmoi:modify-template
{{- /*
Modify template for ~/.bashrc.

Emits the new contents of ~/.bashrc: the original file (from .chezmoi.stdin)
with any prior copy of our managed block removed and any legacy
`. $HOME/.dotfiles/.bashrc` hook line (from the pre-chezmoi init.sh) dropped,
then exactly one fresh block that sources ~/.bashrc.local. Idempotent: after
the first apply, re-running `chezmoi apply` leaves the file byte-identical, so
`chezmoi status`/`verify` stay clean.

The file must literally contain the string "chezmoi:modify-template" (line 1,
kept deliberately untrimmed) or chezmoi treats this as a plain script and pipes
the target file to its stdin instead of running it as a template
(https://github.com/twpayne/chezmoi/issues/4836).
*/ -}}
{{- $marker := `# --- Mersid/dotfiles (managed by chezmoi) ---` -}}
{{- $legacy := `.dotfiles/.bashrc` -}}
{{- $lines := splitList "\n" .chezmoi.stdin -}}
{{- $out := list -}}
{{- $stripping := false -}}
{{- range $line := $lines -}}
  {{- if or (eq $line $marker) (contains $legacy $line) -}}
    {{- $stripping = true -}}
    {{- if contains $legacy $line -}}
      {{- $stripping = false -}}
    {{- end -}}
  {{- else if $stripping -}}
    {{- if eq $line "fi" -}}
      {{- $stripping = false -}}
    {{- end -}}
  {{- else -}}
    {{- $out = append $out $line -}}
  {{- end -}}
{{- end -}}
{{- /* count trailing blank lines and drop them (no `while` in text/template) */ -}}
{{- $drop := 0 -}}
{{- range $i, $line := $out -}}
  {{- if eq $line "" -}}
    {{- $drop = add $drop 1 -}}
  {{- else -}}
    {{- $drop = 0 -}}
  {{- end -}}
{{- end -}}
{{- $n := sub (len $out) $drop -}}
{{- if gt $n 0 -}}
  {{- range $i, $line := $out -}}
    {{- if lt $i $n -}}
      {{- print $line "\n" -}}
    {{- end -}}
  {{- end -}}
  {{- print "\n" -}}
{{- end -}}
{{ $marker }}
if [ -f "$HOME/.bashrc.local" ]; then
	. "$HOME/.bashrc.local"
fi
