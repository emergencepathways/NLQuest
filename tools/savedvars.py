"""
Minimal reader for World of Warcraft SavedVariables files (Lua table syntax).

    from savedvars import load
    data = load("SpeurtochtNL.lua")      # -> {"SpeurtochtNLDB": {...}, "SpeurtochtNLVocab": {...}, ...}

Handles the subset WoW writes: strings, numbers, true/false/nil, nested tables
with ["key"] = value, [number] = value and plain list entries.
"""
import re

_ESC = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "a": "\a", "b": "\b",
        "f": "\f", "v": "\v", "\n": "\n"}


class _Parser:
    def __init__(self, text):
        self.s, self.i, self.n = text, 0, len(text)

    def ws(self):
        s, n = self.s, self.n
        while self.i < n:
            c = s[self.i]
            if c in " \t\r\n,;":
                self.i += 1
            elif s.startswith("--", self.i):
                if s.startswith("--[[", self.i):
                    end = s.find("]]", self.i)
                    self.i = n if end < 0 else end + 2
                else:
                    end = s.find("\n", self.i)
                    self.i = n if end < 0 else end + 1
            else:
                break

    def peek(self):
        self.ws()
        return self.s[self.i] if self.i < self.n else ""

    def expect(self, ch):
        self.ws()
        if self.s[self.i] != ch:
            raise ValueError("expected %r at %d, got %r" % (ch, self.i, self.s[self.i:self.i + 20]))
        self.i += 1

    def string(self):
        q = self.s[self.i]
        self.i += 1
        out = []
        while True:
            c = self.s[self.i]
            if c == "\\":
                nxt = self.s[self.i + 1]
                if nxt.isdigit():
                    m = re.match(r"\d{1,3}", self.s[self.i + 1:])
                    out.append(chr(int(m.group(0))))
                    self.i += 1 + len(m.group(0))
                    continue
                out.append(_ESC.get(nxt, nxt))
                self.i += 2
            elif c == q:
                self.i += 1
                break
            else:
                out.append(c)
                self.i += 1
        raw = "".join(out)
        # Lua strings are byte strings; WoW writes UTF-8.
        try:
            return raw.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            return raw

    def value(self):
        c = self.peek()
        if c in "\"'":
            return self.string()
        if c == "{":
            return self.table()
        m = re.match(r"-?\d+(\.\d+)?([eE][-+]?\d+)?", self.s[self.i:])
        if m:
            self.i += len(m.group(0))
            v = m.group(0)
            return float(v) if ("." in v or "e" in v.lower()) else int(v)
        for word, val in (("true", True), ("false", False), ("nil", None)):
            if self.s.startswith(word, self.i):
                self.i += len(word)
                return val
        raise ValueError("unexpected %r at %d" % (self.s[self.i:self.i + 20], self.i))

    def table(self):
        self.expect("{")
        out, idx = {}, 1
        while self.peek() != "}":
            if self.peek() == "[":
                self.i += 1
                key = self.value()
                self.expect("]")
                self.expect("=")
                out[key] = self.value()
            else:
                m = re.match(r"([A-Za-z_]\w*)\s*=(?!=)", self.s[self.i:])
                if m:
                    self.i += len(m.group(0))
                    out[m.group(1)] = self.value()
                else:
                    out[idx] = self.value()
                    idx += 1
        self.expect("}")
        return out

    def file(self):
        result = {}
        while self.peek():
            m = re.match(r"([A-Za-z_]\w*)\s*=", self.s[self.i:])
            if not m:
                raise ValueError("expected assignment at %d" % self.i)
            self.i += len(m.group(0))
            result[m.group(1)] = self.value()
        return result


def load(path):
    with open(path, encoding="latin-1") as fh:  # keep bytes; strings are re-decoded as UTF-8
        return _Parser(fh.read()).file()
