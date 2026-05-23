shader_type canvas_item;

// 🌟 引入外部的噪音圖片 (記得開啟 repeat_enable 讓圖片可以無限拼接)
uniform sampler2D noise_tex : repeat_enable, filter_linear; 

// 海水顏色層次
uniform vec4 deep_water : source_color = vec4(0.08, 0.35, 0.6, 1.0);    // 深海暗部
uniform vec4 shallow_water : source_color = vec4(0.15, 0.6, 0.8, 1.0);  // 淺海亮部
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);     // 浪花反光

uniform float wave_speed = 0.03; // 整體流速
uniform float wave_scale = 3.0;  // 波浪的密集度 (數值越大，海浪越細碎)

void fragment() {
    // 讓 UV 乘以密集度
    vec2 uv = UV * wave_scale; 
    
    // 🌊 第一層海浪 (往右上角緩慢流動)
    vec2 uv1 = uv + vec2(TIME * wave_speed, TIME * wave_speed * 0.8);
    float noise1 = texture(noise_tex, uv1).r;
    
    // 🌊 第二層海浪 (往左上角流動，速度與方向稍微錯開)
    vec2 uv2 = uv + vec2(-TIME * wave_speed * 0.7, TIME * wave_speed * 1.1);
    float noise2 = texture(noise_tex, uv2).r;
    
    // ✨ 核心魔法：將兩層不同方向的波浪相乘，製造出極度真實的「水面波光網格」
    float combined_noise = noise1 * noise2;
    
    // 🎨 上色階段：根據噪音的深淺，依序塗上 深海 -> 淺海 -> 浪花
    // smoothstep 可以創造出非常柔和的漸層過渡
    vec4 color = mix(deep_water, shallow_water, smoothstep(0.1, 0.4, combined_noise));
    color = mix(color, foam_color, smoothstep(0.45, 0.5, combined_noise)); // 只有最高點才會出現白色浪花
    
    COLOR = color;
}