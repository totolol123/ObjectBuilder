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
    import flash.events.Event;
    import flash.events.KeyboardEvent;
    import flash.ui.ContextMenu;
    import flash.ui.Keyboard;
    
    import otlib.core.otlib_internal;
    import otlib.events.SpriteListEvent;
    
    [Event(name="copy", type="flash.events.Event")]
    [Event(name="paste", type="flash.events.Event")]
    [Event(name="replace", type="otlib.events.SpriteListEvent")]
    [Event(name="export", type="otlib.events.SpriteListEvent")]
    [Event(name="remove", type="otlib.events.SpriteListEvent")]
    
    public class SpriteList extends ListBase
    {
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function SpriteList()
        {
            super();
        }
        
        //--------------------------------------------------------------------------
        // METHODS
        //--------------------------------------------------------------------------
        
        //--------------------------------------
        // Internal
        //--------------------------------------
        
        otlib_internal function onContextMenuSelect(index:int, type:String):void
        {
            if (index != -1 && dataProvider) {
                var item:ListItem = ListItem( dataProvider.getItemAt(index) );
                var event:Event;
                
                switch(type)
                {
                    case Event.COPY:
                        event = new Event(Event.COPY);
                        break;
                    
                    case Event.PASTE:
                        event = new Event(Event.PASTE);
                        break;
                    
                    case SpriteListEvent.REPLACE:
                        event = new SpriteListEvent(SpriteListEvent.REPLACE);
                        break;
                    
                    case SpriteListEvent.EXPORT:
                        event = new SpriteListEvent(SpriteListEvent.EXPORT);
                        break;
                    
                    case SpriteListEvent.REMOVE:
                        event = new SpriteListEvent(SpriteListEvent.REMOVE);
                        break;
                }
                
                if (event)
                    dispatchEvent(event);
            }
        }
        
        otlib_internal function onContextMenuDisplaying(index:int, menu:ContextMenu):void
        {
            if (multipleSelected) {
                menu.items[0].enabled = false; // Copy
                menu.items[1].enabled = false; // Paste
            }
            else
                setSelectedIndex(index, true);
            
            if (hasEventListener(SpriteListEvent.DISPLAYING_CONTEXT_MENU))
                dispatchEvent(new SpriteListEvent(SpriteListEvent.DISPLAYING_CONTEXT_MENU));
        }
        
        //--------------------------------------
        // Event Handlers
        //--------------------------------------
        
        override protected function keyDownHandler(event:KeyboardEvent):void
        {
            super.keyDownHandler(event);
            
            switch(event.keyCode)
            {
                case Keyboard.C:
                    if (event.ctrlKey) dispatchEvent(new Event(Event.COPY));
                    break;
                
                case Keyboard.V:
                    if (event.ctrlKey) dispatchEvent(new Event(Event.PASTE));
                    break;
                
                case Keyboard.DELETE:
                    dispatchEvent(new SpriteListEvent(SpriteListEvent.REMOVE));
                    break;
            }
        }
    }
}
