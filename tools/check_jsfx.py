#!/usr/bin/env python3
"""A structural check over the JSFX source.

There is no EEL2 compiler here, so this does what can be done without one:
strips comments and strings, checks every bracket balances, checks that each
function is defined before it is first called and that nothing calls a name
that is neither a function in this file nor an EEL2/JSFX builtin, and checks
that every function is called with the number of arguments it declares.

    python3 tools/check_jsfx.py "jsfx/Starting Blocks.jsfx"
"""
import re, sys

BUILTINS = {
    # maths
    'sin','cos','tan','asin','acos','atan','atan2','sqrt','pow','exp','log',
    'log10','abs','min','max','sign','floor','ceil','invsqrt','rand','sqr',
    # memory / control
    'memset','memcpy','freembuf','mem_set_values','mem_get_values','stack_push',
    'stack_pop','stack_peek','stack_exch','loop','while',
    # strings
    'strlen','strcpy','strcat','strcmp','stricmp','strncmp','strnicmp','strcpy_from',
    'strcpy_substr','str_getchar','str_setchar','sprintf','match','matchi','printf',
    'strncpy','strncat','str_delsub','str_insert','gfx_printf',
    # files
    'file_open','file_close','file_avail','file_riff','file_text','file_mem',
    'file_var','file_string','file_rewind',
    # midi / jsfx
    'midisend','midisend_buf','midisend_str','midirecv','midirecv_buf','midirecv_str',
    'midisyx','slider','slider_next_chg','sliderchange','spl','export_buffer_to_project',
    'get_host_placement','time','time_precise',
    # gfx
    'gfx_set','gfx_rect','gfx_line','gfx_lineto','gfx_rectto','gfx_circle','gfx_arc',
    'gfx_triangle','gfx_roundrect','gfx_drawnumber','gfx_drawchar','gfx_drawstr',
    'gfx_measurestr','gfx_measurechar','gfx_setfont','gfx_getfont','gfx_blit',
    'gfx_blitext','gfx_getimgdim','gfx_setimgdim','gfx_loadimg','gfx_gradrect',
    'gfx_muladdrect','gfx_deltablit','gfx_transformblit','gfx_getpixel','gfx_setpixel',
    'gfx_getchar','gfx_showmenu','gfx_setcursor','gfx_blurto','gfx_clienttoscreen',
    'gfx_screentoclient','gfx_setscale','gfx_getdropfile',
}

def strip(src):
    """Blank out comments and string literals, keeping line structure."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i+1] == '/':
            while i < n and src[i] != '\n':
                out.append(' '); i += 1
        elif c == '/' and i + 1 < n and src[i+1] == '*':
            out.append('  '); i += 2
            while i + 1 < n and not (src[i] == '*' and src[i+1] == '/'):
                out.append('\n' if src[i] == '\n' else ' '); i += 1
            out.append('  '); i += 2
        elif c == '"':
            out.append(' '); i += 1
            while i < n and src[i] != '"':
                if src[i] == '\\' and i + 1 < n:
                    out.append('  '); i += 2; continue
                out.append('\n' if src[i] == '\n' else ' '); i += 1
            out.append(' '); i += 1
        elif c == "'":
            out.append(' '); i += 1
            while i < n and src[i] != "'":
                out.append(' '); i += 1
            out.append(' '); i += 1
        else:
            out.append(c); i += 1
    return ''.join(out)

def main(path):
    raw = open(path, encoding='utf-8').read()
    errs = []

    # The prose header runs until the first section tag, and is not code.
    m = re.search(r'^@init', raw, re.M)
    if not m:
        print('no @init section'); return 1
    head, code = raw[:m.start()], raw[m.start():]
    src = strip(code)
    base_line = head.count('\n')

    # brackets
    stack = []
    for idx, ch in enumerate(src):
        if ch in '([':
            stack.append((ch, idx))
        elif ch in ')]':
            want = '(' if ch == ')' else '['
            if not stack:
                errs.append(f'line {base_line + src[:idx].count(chr(10)) + 1}: stray {ch!r}')
            elif stack[-1][0] != want:
                errs.append(f'line {base_line + src[:idx].count(chr(10)) + 1}: {ch!r} closes {stack[-1][0]!r}')
                stack.pop()
            else:
                stack.pop()
    for ch, idx in stack:
        errs.append(f'line {base_line + src[:idx].count(chr(10)) + 1}: unclosed {ch!r}')

    # function definitions, in source order
    defs = {}
    for m in re.finditer(r'\bfunction\s+([A-Za-z_][A-Za-z0-9_.]*)\s*\(([^)]*)\)', src):
        name = m.group(1)
        params = [p for p in m.group(2).replace(',', ' ').split() if p]
        if name in defs:
            errs.append(f'{name}: defined twice')
        defs[name] = (len(params), m.start())

    def argcount(src, open_idx):
        """Count top-level commas in the call starting at open_idx."""
        depth, args, seen = 0, 1, False
        i = open_idx
        while i < len(src):
            c = src[i]
            if c in '([':
                depth += 1
            elif c in ')]':
                depth -= 1
                if depth == 0:
                    return 0 if not seen else args
            elif c == ',' and depth == 1:
                args += 1
            elif not c.isspace() and depth == 1:
                seen = True
            i += 1
        return -1

    KEYWORDS = {'function', 'local', 'instance', 'globals', 'global', 'this'}
    for m in re.finditer(r'\b([A-Za-z_][A-Za-z0-9_.]*)\s*\(', src):
        name, at = m.group(1), m.start()
        if name in KEYWORDS or name in BUILTINS:
            continue
        # skip the name in its own "function foo(" header
        if re.search(r'\bfunction\s+$', src[:at]):
            continue
        line = base_line + src[:at].count('\n') + 1
        if name not in defs:
            errs.append(f'line {line}: call to undefined {name}()')
            continue
        want, defined_at = defs[name]
        if at < defined_at:
            errs.append(f'line {line}: {name}() called before it is defined')
        got = argcount(src, m.end() - 1)
        if got != want:
            errs.append(f'line {line}: {name}() takes {want} args, called with {got}')

    errs += layout(raw)

    for e in errs:
        print('  ' + e)
    print(f'{len(defs)} functions, {len(errs)} problem(s)')
    return 1 if errs else 0


def layout(raw):
    """Re-derives every widget rectangle in @gfx and checks it fits.

    The panels are laid out by hand in pixels, so the way this breaks is a row
    quietly running off the bottom of its box or off the right of the window
    the first time a control is added to it.
    """
    errs = []
    gfx = raw[raw.index('@gfx'):]

    m = re.search(r'@gfx\s+(\d+)\s+(\d+)', gfx)
    win_w, win_h = (int(m.group(1)), int(m.group(2))) if m else (1000, 620)

    m = re.search(r'rectf\(6,\s*(\d+),\s*gfx_w - 12,\s*(\d+)\)', gfx)
    if not m:
        return ['could not find the panel box']
    panel_top, panel_h = int(m.group(1)), int(m.group(2))
    panel_bot = panel_top + panel_h

    m = re.search(r'sel_cat == 0 \? panel_chord\s*\((\d+),\s*(\d+)\)', gfx)
    panel_x, panel_y = (int(m.group(1)), int(m.group(2))) if m else (20, panel_top)

    # how many buttons each named count stands for
    counts = {'n_rates': 7, 'n_mods': 3, 'n_mels': 7, 'n_shapes': 3, 'n_drp': 9,
              'n_drs': 9, 'n_btone': 4, 'n_invs': 4, 'n_fams': 8, 'n_dia': 9, '7': 7}

    for fn in re.finditer(r'function (panel_\w+)\(x y\)(.*?)\n\);', gfx, re.S):
        name, body = fn.group(1), fn.group(2)
        bottoms = [0]
        for m in re.finditer(
                r'\b(?:btn_row|btn|stepper|hslider)\([^,]*,\s*y\+(\d+),\s*\d+,\s*(\d+)',
                body):
            bottoms.append(int(m.group(1)) + int(m.group(2)))
        # a ctl_ is a label then a 24px control 14px under it
        # a ctl_ is a label with a 24px control 14px under it, except
        # ctl_follow, which is a bare button at the y it is handed
        for m in re.finditer(r'ctl_(\w+)\s*\([^,]*,\s*y([+-])(\d+)', body):
            at = int(m.group(3)) * (1 if m.group(2) == '+' else -1)
            bottoms.append(at + 24 if m.group(1) == 'follow' else at + 14 + 24)
        bottom = panel_y + max(bottoms)
        if bottom > panel_bot:
            errs.append(f'{name}: reaches y={bottom}, the panel box ends at {panel_bot}')

        for m in re.finditer(
                r'btn_row\(x(?:\s*\+\s*(\d+))?,\s*y\+\d+,\s*(\d+),\s*\d+,\s*(\d+),'
                r'\s*#\w+,\s*\w+,\s*(\w+)', body):
            n = counts.get(m.group(4))
            if n is None:
                continue
            off, w, gap = int(m.group(1) or 0), int(m.group(2)), int(m.group(3))
            right = panel_x + off + n * (w + gap) - gap
            if right > win_w - 8:
                errs.append(f'{name}: a row of {n} reaches x={right}, the window is {win_w} wide')

    # the rows outside the panel, drawn straight in the frame
    for m in re.finditer(r'btn_row\((\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),'
                         r'\s*#\w+,\s*\w+,\s*(\w+)', gfx):
        x, y, w, h, gap = (int(m.group(i)) for i in range(1, 6))
        n = counts.get(m.group(6)) or {'n_root_names': 18, 'n_cats': 6}.get(m.group(6))
        if n is None:
            continue
        if x + n * (w + gap) - gap > win_w - 8:
            errs.append(f'a row of {n} at y={y} runs off the right of the window')
        if y + h > win_h:
            errs.append(f'a row at y={y} runs off the bottom of the window')

    return errs

if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
