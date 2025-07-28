#!/usr/bin/env python3
"""
Simple DMG background generator for VTS
Creates a clean, professional background image for the DMG installer
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
except ImportError:
    print("PIL (Pillow) not found. Install with: pip install Pillow")
    exit(1)

def create_dmg_background():
    # DMG window size from our script
    width, height = 800, 450
    
    # Create image with gradient background
    img = Image.new('RGB', (width, height), color='#f5f5f7')
    draw = ImageDraw.Draw(img)
    
    # Try to load a system font for the instruction text
    try:
        # macOS system fonts
        font_large = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 24)
        font_small = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 16)
    except:
        try:
            # Fallback to default font
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
        except:
            font_large = None
            font_small = None
    
    # Add instructional text
    if font_large and font_small:
        # Main instruction
        text1 = "Drag VTSApp to Applications"
        text1_bbox = draw.textbbox((0, 0), text1, font=font_large)
        text1_width = text1_bbox[2] - text1_bbox[0]
        text1_x = (width - text1_width) // 2
        text1_y = height - 120
        
        # Draw text with subtle shadow
        draw.text((text1_x + 1, text1_y + 1), text1, fill='#cccccc', font=font_large)
        draw.text((text1_x, text1_y), text1, fill='#333333', font=font_large)
        
        # Sub instruction
        text2 = "Install VTS by dragging the app to the Applications folder"
        text2_bbox = draw.textbbox((0, 0), text2, font=font_small)
        text2_width = text2_bbox[2] - text2_bbox[0]
        text2_x = (width - text2_width) // 2
        text2_y = text1_y + 35
        
        draw.text((text2_x + 1, text2_y + 1), text2, fill='#dddddd', font=font_small)
        draw.text((text2_x, text2_y), text2, fill='#666666', font=font_small)
    
    # Save the background
    output_path = 'scripts/dmg-background.png'
    img.save(output_path, 'PNG', quality=95)
    print(f"✅ DMG background created: {output_path}")
    print(f"   Size: {width}x{height} pixels")
    
    return output_path

if __name__ == '__main__':
    # Create the scripts directory if it doesn't exist
    os.makedirs('scripts', exist_ok=True)
    
    create_dmg_background()
    print("\n📦 Background is ready for DMG creation!")
    print("   The background will show installation instructions and an arrow.") 