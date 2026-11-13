package markdown

import "core:fmt"
import "core:strconv"
import commonmark "vendor:commonmark"

ListPrefix :: struct {
	valid: bool,
	content_start: int,
	indent: string,
	marker: string,
	ordered: bool,
	number: int,
}

list_prefix :: proc(line: string) -> ListPrefix {
	at := 0
	for at < len(line) && (line[at] == ' ' || line[at] == '\t') do at += 1
	prefix := ListPrefix{indent = line[:at]}
	start := at
	if at >= len(line) do return prefix
	if line[at] == '-' || line[at] == '*' || line[at] == '+' {
		at += 1
	} else {
		for at < len(line) && line[at] >= '0' && line[at] <= '9' do at += 1
		if at == start || at-start > 9 || at >= len(line) || (line[at] != '.' && line[at] != ')') do return prefix
		prefix.ordered = true
		prefix.number, _ = strconv.parse_int(line[start:at])
		at += 1
	}
	if at >= len(line) || (line[at] != ' ' && line[at] != '\t') do return prefix
	prefix.marker = line[start:at]
	for at < len(line) && (line[at] == ' ' || line[at] == '\t') do at += 1
	prefix.content_start = at
	prefix.valid = true
	return prefix
}

next_list_prefix :: proc(prefix: ListPrefix) -> string {
	if prefix.ordered do return fmt.tprintf("%s%d%c ", prefix.indent, prefix.number+1, prefix.marker[len(prefix.marker)-1])
	return fmt.tprintf("%s%s ", prefix.indent, prefix.marker)
}

node_in_list :: proc(node: ^commonmark.Node) -> bool {
	for current := node; current != nil; current = commonmark.node_parent(current) {
		if commonmark.node_get_type(current) == .Item do return true
	}
	return false
}

source_line_in_list :: proc(root: ^commonmark.Node, line: int) -> bool {
	if root == nil do return false
	kind := commonmark.node_get_type(root)
	if kind == .Code_Block || kind == .HTML_Block do return false
	if kind == .Item && int(commonmark.node_get_start_line(root)) == line do return true
	for child := commonmark.node_first_child(root); child != nil; child = commonmark.node_next(child) {
		if source_line_in_list(child, line) do return true
	}
	return false
}
