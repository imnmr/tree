package main

import "core:fmt"
import "base:intrinsics"
import "base:runtime"
import "core:mem/virtual"
import rl "vendor:raylib"

Node :: struct($T: typeid) where intrinsics.type_is_ordered_numeric(T) {
	value:  T,
	height: int,
	factor: int,
	left:   ^Node(T),
	right:  ^Node(T),
}

node_make :: proc(value: $T, allocator: runtime.Allocator) -> ^Node(T) {
	node := new(Node(T), allocator = allocator)
	node.value  = value
	node.height = 1
	node.factor = 0
	node.left   = nil
	node.right  = nil

	return node
}

node_add_node :: proc(n: ^Node($T), node: ^Node(T)) {
	p := &n.left if node.value < n.value else &n.right
	if p^ == nil {
		p^ = node
	} else {
		node_add_node(p^, node)
	}

	left_height  := n.left.height  if n.left  != nil else 0
	right_height := n.right.height if n.right != nil else 0

	n.height = max(left_height, right_height) + 1
}

node_add_value :: proc(n: ^Node($T), value: T, allocator: runtime.Allocator) {
	node_add_node(n, node_make(value, allocator))
}

node_add :: proc {
	node_add_node,
	node_add_value,
}

Tree :: struct($T: typeid) {
	allocator: runtime.Allocator,
	root:      ^Node(T),
}

tree_make :: proc(value: $T, allocator: runtime.Allocator) -> Tree(T) {
	return {allocator = allocator, root = node_make(value, allocator)}
}

tree_add_node :: proc(t: ^Tree($T), node: ^Node(T)) {
	node_add_node(t.root, node)
}

tree_add_value :: proc(t: ^Tree($T), value: T) {
	node_add_value(t.root, value, t.allocator)
}

tree_add :: proc {
	tree_add_node,
	tree_add_value,
}

main :: proc() {
	node_arena: virtual.Arena

	node_arena_err := virtual.arena_init_static(&node_arena)
	ensure(node_arena_err == nil)
	defer virtual.arena_destroy(&node_arena)

	node_arena_allocator := virtual.arena_allocator(&node_arena)

	tree := tree_make(50, node_arena_allocator)
	tree_add(&tree, 80)
	tree_add(&tree, 20)
	tree_add(&tree, 90)
	tree_add(&tree, 70)
	tree_add(&tree, 10)

	//
	// Raylib setup
	//

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1440, 810, "Tree")
	defer rl.CloseWindow()

	rl.MaximizeWindow()

	screen_size := rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	camera := rl.Camera2D {
		zoom   = 1,
		offset = screen_size / 2,
	}

	for !rl.WindowShouldClose() {
		screen_size.x = f32(rl.GetScreenWidth())
		screen_size.y = f32(rl.GetScreenHeight())

		camera.offset = screen_size / 2

		mouse_screen := rl.GetMousePosition()
		mouse_world  := rl.GetScreenToWorld2D(mouse_screen, camera)

		// Input handling
		{
			if rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) {
				if rl.IsKeyPressed(.EQUAL) || rl.IsKeyPressedRepeat(.EQUAL) {
					camera.zoom = min(10, camera.zoom * 1.2)
				} else if rl.IsKeyPressed(.MINUS) || rl.IsKeyPressedRepeat(.MINUS) {
					camera.zoom = max(0.1, camera.zoom * 0.8)
				}
			}

			if rl.IsMouseButtonDown(.LEFT) {
				mouse_delta := rl.GetMouseDelta()
				camera.target -= mouse_delta / camera.zoom
			}
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.BLACK)

		// World drawing
		{
			draw_node :: proc(n: ^Node($T), position: rl.Vector2) {
				size   :: rl.Vector2{32, 32}
				margin :: 64

				padding   := f32(16 * f32(u32(2) << u32(n.height) - 1))
				left_pos  := position + {-padding, margin}
				right_pos := position + { padding, margin}

				value := fmt.ctprint(n.value, n.height)

				if n.left  != nil {
					rl.DrawLineV(position, left_pos, rl.RED)
					draw_node(n.left,  left_pos)
				}

				if n.right != nil {
					rl.DrawLineV(position, right_pos, rl.RED)
					draw_node(n.right, right_pos)
				}

				rl.DrawRectangleV(position - size / 2, size, rl.RED)
				rl.DrawTextEx(rl.GetFontDefault(), value, position - size / 2 + 1, 12, 1, rl.WHITE)
			}

			rl.BeginMode2D(camera)
			defer rl.EndMode2D()

			draw_node(tree.root, {0, 0})
		}

		// UI Drawing
		{
			// TODO
		}

		free_all(context.temp_allocator)
	}
}
