/*
*  Copyright (c) 2015 Object Builder <https://github.com/Mignari/ObjectBuilder>
* 
*  Permission is hereby granted, free of charge, to any person obtaining a copy
*  of this software and associated documentation files (the "Software"), to deal
*  in the Software without restriction, including without limitation the rights
*  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
*  copies of the Software, and to permit persons to whom the Software is
*  furnished to do so, subject to the following conditions:
* 
*  The above copyright notice and this permission notice shall be included in
*  all copies or substantial portions of the Software.
* 
*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
*  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
*  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
*  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
*  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
*  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
*  THE SOFTWARE.
*/

package otlib.sprites
{
    import flash.display.BitmapData;
    import flash.geom.Rectangle;
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    
    import nail.errors.NullArgumentError;
    
    import otlib.core.otlib_internal;
    
    use namespace otlib_internal;
    
    /**
     * The Sprite class represents an image with 32x32 pixels.
     */
    public class Sprite
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        otlib_internal var m_id:uint;
        
        private var m_transparent:Boolean;
        private var m_compressedPixels:ByteArray;
        
        //--------------------------------------
        // Getters / Setters
        //--------------------------------------
        
        /** The id of the sprite. This value specifies the index in the spr file. **/
        public function get id():uint { return m_id; }
        
        /** Indicates if the sprite does not have colored pixels. **/
        public function get isEmpty():Boolean { return (m_compressedPixels.length == 0); }
        
        /** Specifies whether the sprite supports per-pixel transparency. **/
        public function get transparent():Boolean { return m_transparent; }
        public function set transparent(value:Boolean):void
        {
            if (m_transparent != value) {
                var pixels:ByteArray = uncompressPixels(m_compressedPixels, m_transparent);
                m_transparent = value;
                m_compressedPixels = compressPixels(pixels, m_transparent);
            }
        }
        
        public function get pixels():ByteArray
        {
            return uncompressPixels(m_compressedPixels, m_transparent);
        }
        
        public function set pixels(value:ByteArray):void
        {
            if (!value)
                throw new NullArgumentError("pixels");
            
            m_compressedPixels = compressPixels(value, m_transparent);
        }
        
        internal function get length():uint { return m_compressedPixels.length;}
        internal function get compressedPixels():ByteArray { return m_compressedPixels; }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function Sprite(id:uint, transparent:Boolean)
        {
            m_id = id;
            m_transparent = transparent;
            m_compressedPixels = new ByteArray();
            m_compressedPixels.endian = Endian.LITTLE_ENDIAN;
        }
        
        //--------------------------------------------------------------------------
        // METHODS
        //--------------------------------------------------------------------------
        
        //--------------------------------------
        // Public
        //--------------------------------------
        
        /**
         * Returns the <code>id</code> string representation of the <code>Sprite</code>.
         */
        public function toString():String
        {
            return m_id.toString();
        }
        
        public function clone():Sprite
        {
            var sprite:Sprite = new Sprite(m_id, m_transparent);
            m_compressedPixels.position = 0;
            m_compressedPixels.readBytes(sprite.m_compressedPixels);
            return sprite;
        }
        
        public function clear():void
        {
            if (m_compressedPixels)
                m_compressedPixels.clear();
        }
        
        public function dispose():void
        {
            if (m_compressedPixels)
                m_compressedPixels.clear();
        }
        
        //--------------------------------------------------------------------------
        // STATIC
        //--------------------------------------------------------------------------
        
        public static const DEFAULT_SIZE:uint = 32;
        public static const SPRITE_DATA_SIZE:uint = 4096; // DEFAULT_WIDTH * DEFAULT_HEIGHT * 4 channels;
        public static const RECTANGLE:Rectangle = new Rectangle(0, 0, DEFAULT_SIZE, DEFAULT_SIZE);
        public static const BITMAP:BitmapData = new BitmapData(DEFAULT_SIZE, DEFAULT_SIZE, true, 0);
        
        public static function compressPixels(pixels:ByteArray, transparent:Boolean):ByteArray
        {
            if (!pixels)
                throw new NullArgumentError("pixels");
            
            if (pixels.length != SPRITE_DATA_SIZE)
                throw new Error("Invalid sprite pixels length");
            
            var compressedPixels:ByteArray = new ByteArray();
            compressedPixels.endian = Endian.LITTLE_ENDIAN;
            
            pixels.position = 0;
            
            var alphaCount:uint = 0;
            var chunkSize:uint = 0;
            var coloredPos:uint = 0;
            var finishOffset:uint = 0;
            var length:uint = pixels.length / 4;
            var i:uint = 0;
            
            while (i < length) {
                chunkSize = 0;
                
                // Reads transparent pixels
                for (; i < length; i++) {
                    pixels.position = i * 4;
                    
                    // Checks if the pixel is not transparent
                    if (pixels.readUnsignedInt() != 0)
                        break;
                    
                    alphaCount++;
                    chunkSize++;
                }
                
                // Reads colored pixels
                if (alphaCount < length && i < length) {
                    compressedPixels.writeShort(chunkSize); // Writes the length of the transparent pixels
                    coloredPos = compressedPixels.position; // Save colored position 
                    compressedPixels.position += 2;         // Skip colored short
                    chunkSize = 0;
                    
                    for (; i < length; i++) {
                        pixels.position = i * 4;
                        
                        var color:uint = pixels.readUnsignedInt();
                        
                        // Checks if the pixel is transparent
                        if (color == 0)
                            break;
                        
                        compressedPixels.writeByte(color >> 16 & 0xFF); // Red
                        compressedPixels.writeByte(color >> 8 & 0xFF);  // Green
                        compressedPixels.writeByte(color & 0xFF);       // Blue
                        
                        if (transparent)
                            compressedPixels.writeByte(color >> 24 & 0xFF); // Alpha
                        
                        chunkSize++;
                    }
                    
                    finishOffset = compressedPixels.position;
                    compressedPixels.position = coloredPos; // Go back to chunksize indicator
                    compressedPixels.writeShort(chunkSize); // Writes the length of he colored pixels
                    compressedPixels.position = finishOffset;
                }
            }
            return compressedPixels;
        }
        
        public static function uncompressPixels(compressedPixels:ByteArray, transparent:Boolean):ByteArray
        {
            if (!compressedPixels)
                throw new NullArgumentError("compressedPixels");
            
            var pixels:ByteArray = new ByteArray();
            var read:uint = 0;
            var write:uint = 0;
            var transparentPixels:uint = 0;
            var coloredPixels:uint = 0;
            var bitPerPixel:uint = transparent ? 4 : 3;
            var length:uint = compressedPixels.length;
            var i:int = 0;
            
            compressedPixels.position = 0;
            
            for (read = 0; read < length; read += 4 + (bitPerPixel * coloredPixels)) {
                transparentPixels = compressedPixels.readUnsignedShort();
                coloredPixels = compressedPixels.readUnsignedShort();
                
                for (i = 0; i < transparentPixels; i++) {
                    pixels[write++] = 0x00; // Alpha
                    pixels[write++] = 0x00; // Red
                    pixels[write++] = 0x00; // Green
                    pixels[write++] = 0x00; // Blue
                }
                
                for (i = 0; i < coloredPixels; i++) {
                    var red:uint = compressedPixels.readUnsignedByte();                         // Red
                    var green:uint = compressedPixels.readUnsignedByte();                       // Green
                    var blue:uint = compressedPixels.readUnsignedByte();                        // Blue
                    var alpha:uint = transparent ? compressedPixels.readUnsignedByte() : 0xFF;  // Alpha
                    
                    pixels[write++] = alpha;    // Alpha
                    pixels[write++] = red;      // Red
                    pixels[write++] = green;    // Green
                    pixels[write++] = blue;     // Blue
                }
            }
            
            while(write < SPRITE_DATA_SIZE) {
                pixels[write++] = 0x00; // Alpha
                pixels[write++] = 0x00; // Red
                pixels[write++] = 0x00; // Green
                pixels[write++] = 0x00; // Blue	
            }
            return pixels;
        }
        
        public static function createFromBitmap(bitmap:BitmapData, transparent:Boolean):Vector.<Sprite>
        {
            if (!bitmap)
                throw new NullArgumentError("bitmap");
            
            if ((bitmap.width % DEFAULT_SIZE) != 0 || (bitmap.height % DEFAULT_SIZE) != 0)
                throw new ArgumentError("Invalid bitmap size.");
            
            var columns:uint = uint(bitmap.width / DEFAULT_SIZE);
            var rows:uint = uint(bitmap.height / DEFAULT_SIZE);
            var rect:Rectangle = new Rectangle(0, 0, DEFAULT_SIZE, DEFAULT_SIZE);
            var sprites:Vector.<Sprite> = new Vector.<Sprite>(columns * rows, true);
            var index:uint = 0;
            
            for (var y:uint = 0; y < rows; y++) {
                for (var x:uint = 0; x < columns; x++) {
                    var sprite:Sprite = new Sprite(index, transparent);
                    rect.x = x * DEFAULT_SIZE;
                    rect.y = y * DEFAULT_SIZE;
                    sprite.pixels = bitmap.getPixels(rect);
                    sprites[index] = sprite;
                    index++;
                }
            }
            return sprites;
        }
    }
}
