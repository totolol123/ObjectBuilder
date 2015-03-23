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

package otlib.utils
{
    import flash.display.BitmapData;
    import flash.utils.ByteArray;
    
    import otlib.components.IListObject;
    import otlib.things.ThingType;
    
    public class ThingListItem implements IListObject
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        public var thing:ThingType;
        public var pixels:ByteArray;
        
        private var m_bitmap:BitmapData;
        
        //--------------------------------------
        // Getters / Setters 
        //--------------------------------------
        
        public function get id():uint { return thing ? thing.id : 0; }
        
        public function get bitmap():BitmapData
        {
            if (pixels && thing && !m_bitmap) {
                pixels.position = 0;
                m_bitmap = new BitmapData(Math.max(32, thing.width * 32), Math.max(32, thing.height * 32), true, 0);
                if (thing.width != 0 &&
                    thing.height != 0 &&
                    pixels.length == (m_bitmap.width * m_bitmap.height * 4)) {
                    m_bitmap.setPixels(m_bitmap.rect, pixels);
                }
            }
            return m_bitmap;
        }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function ThingListItem()
        {
        }
    }
}
