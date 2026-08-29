shader_type canvas_item;

// Màn tối phủ toàn màn hình, khoét một lỗ bo tròn (spotlight) tại hole_rect.
// hole_rect: x, y, w, h theo pixel màn hình.
uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 0.72);
uniform vec4 hole_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform float corner_radius = 14.0;
uniform float feather = 10.0;
// Kích thước control Dim (= viewport thiết kế). Cần để đổi UV → tọa độ canvas,
// vì FRAGCOORD là pixel cửa sổ thật, lệch khi stretch mode canvas_items scale.
uniform vec2 screen_size = vec2(0.0, 0.0);

void fragment() {
	vec2 p = (screen_size.x > 0.0) ? UV * screen_size : FRAGCOORD.xy;
	vec2 center = hole_rect.xy + hole_rect.zw * 0.5;
	vec2 hsz = max(hole_rect.zw * 0.5 - vec2(corner_radius), vec2(0.0));
	vec2 d = abs(p - center) - hsz;
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - corner_radius;
	float a = (hole_rect.z <= 0.0) ? 1.0 : smoothstep(0.0, feather, dist);
	COLOR = vec4(dim_color.rgb, dim_color.a * a);
}
