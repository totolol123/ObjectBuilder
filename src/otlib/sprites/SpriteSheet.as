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
    
    import nail.errors.NullOrEmptyArgumentError;
    import nail.utils.isNullOrEmpty;
    
    import otlib.geom.Rect;
    import otlib.otml.OTMLNode;
    
    public class SpriteSheet extends BitmapData
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        private var m_textures:Vector.<Rect>;
        
        //--------------------------------------
        // Getters / Setters
        //--------------------------------------
        
        public function get textures():Vector.<Rect> { return m_textures; }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function SpriteSheet(width:int, height:int, textures:Vector.<Rect>)
        {
            super(width, height, true, 0);
            
            if (isNullOrEmpty(textures))
                throw new NullOrEmptyArgumentError("textures");
            
            m_textures = textures;
        }
        
        //--------------------------------------------------------------------------
        // METHODS
        //--------------------------------------------------------------------------
        
        //--------------------------------------
        // Public
        //--------------------------------------
        
        public function serialize():OTMLNode
        {
            var node:OTMLNode = new OTMLNode();
            node.tag = "SpriteSheet";
            
            var length:uint = m_textures.length;
            for (var i:int = 0; i < length; i++) {
                var rect:Rect = m_textures[i];
                var rectNode:OTMLNode = new OTMLNode();
                rectNode.tag = "Texture";
                rectNode.writeAt("index", i);
                rectNode.writeAt("x", rect.x);
                rectNode.writeAt("y", rect.y);
                rectNode.writeAt("width", rect.width);
                rectNode.writeAt("height", rect.height);
                node.addChild(rectNode);
            }
            return node;
        }
        
        public function unserialize(node:OTMLNode):Boolean
        {
            return true;
        }
    }
}
