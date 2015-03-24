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

package otlib.components
{
    import flash.display.BitmapData;
    import flash.geom.Rectangle;
    
    public class ListItem
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        public var id:uint;
        public var name:String;
        public var pixels:Vector.<uint>;
        
        protected var m_bitmap:BitmapData;
        private var m_width:uint;
        private var m_height:uint;
        
        public function get width():uint { return m_width; }
        public function set width(value:uint):void
        {
            if (value == 0)
                throw new ArgumentError("Invalid width.");
            
            m_width = value;
        }
        
        public function get height():uint { return m_height; }
        public function set height(value:uint):void
        {
            if (value == 0)
                throw new ArgumentError("Invalid height.");
            
            m_height = value;
        }
        
        //--------------------------------------
        // Getters / Setters
        //--------------------------------------
        
        public function get bitmap():BitmapData
        {
            if (m_bitmap)
                return m_bitmap;
            
            if (m_width == 0 || m_height == 0 || pixels == null || pixels.length == 0)
                return null;
            
            RECTANGLE.width = m_width;
            RECTANGLE.height = m_height;
            m_bitmap = new BitmapData(m_width, m_height, true, 0x00000000);
            m_bitmap.setVector(RECTANGLE, pixels);
            pixels = null;
            return m_bitmap; 
        }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function ListItem()
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
            if (name != null)
                return id.toString() + " - " + name;
            
            return id.toString();
        }
        
        //--------------------------------------------------------------------------
        // STATIC
        //--------------------------------------------------------------------------
        
        private static const RECTANGLE:Rectangle = new Rectangle();
    }
}
