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
    import flash.utils.ByteArray;
    
    import nail.errors.NullArgumentError;
    
    import otlib.components.IListObject;
    import otlib.utils.SpriteUtils;
    
    public class SpriteData implements IListObject
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        private var m_id:uint;
        private var m_pixels:ByteArray;
        private var m_bitmap:BitmapData;
        
        //--------------------------------------
        // Getters / Setters
        //--------------------------------------
        
        public function get id():uint { return m_id; }
        public function set id(value:uint):void { m_id = value; }
        
        public function get pixels():ByteArray { return m_pixels; }
        public function set pixels(value:ByteArray):void
        {
            if (!value)
                throw new NullArgumentError("pixels");
            
            if (value.length != Sprite.PIXEL_DATA_SIZE)
                throw new ArgumentError("Invalid pixel data size.");
            
            m_pixels = value;
            m_bitmap = null;
        }
        
        public function get bitmap():BitmapData
        {
            if (!m_bitmap)
                m_bitmap = Sprite.BITMAP.clone();
            
            if (m_pixels) {
                m_pixels.position = 0;
                m_bitmap.setPixels(Sprite.RECTANGLE, m_pixels);
            }
            return m_bitmap;
        }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function SpriteData()
        {
        }
        
        //--------------------------------------------------------------------------
        // METHODS
        //--------------------------------------------------------------------------
        
        //--------------------------------------
        // Public
        //--------------------------------------
        
        public function toString():String
        {
            return "[object ThingData id="+id+"]";
        }
        
        public function isEmpty():Boolean
        {
            return SpriteUtils.isEmpty(this.bitmap);
        }
        
        public function clone():SpriteData
        {
            var pixels:ByteArray;
            if (m_pixels) {
                pixels = new ByteArray();
                m_pixels.position = 0;
                m_pixels.readBytes(pixels, 0, m_pixels.bytesAvailable);
            }
            
            var sd:SpriteData = new SpriteData();
            sd.m_id = m_id;
            sd.m_pixels = pixels;
            sd.m_bitmap = m_bitmap ? m_bitmap.clone() : null;
            return sd;
        }
        
        //--------------------------------------------------------------------------
        // STATIC
        //--------------------------------------------------------------------------
        
        public static function create(id:uint, pixels:ByteArray):SpriteData
        {
            var sd:SpriteData = new SpriteData();
            sd.id = id;
            sd.pixels = pixels;
            return sd;
        }
        
        public static function createEmpty(id:uint = 0):SpriteData
        {
            var sd:SpriteData = new SpriteData();
            sd.id = id;
            sd.pixels = Sprite.BITMAP.getPixels(Sprite.RECTANGLE);
            return sd;
        }
    }
}
