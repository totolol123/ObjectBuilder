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
    import flash.utils.Dictionary;
    
    import mx.collections.ArrayCollection;
    import mx.events.FlexEvent;
    
    import spark.components.List;
    
    [Exclude(kind="property", name="dataProvider")]
    
    public class ListBase extends List
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        private var m_collection:ArrayCollection;
        private var m_ensureIdIsVisible:uint = uint.MAX_VALUE;
        private var m_scrollSave:ScrollPosition;
        private var m_contextMenuEnabled:Boolean = true;
        private var m_minId:uint;
        private var m_maxId:uint;
        
        //--------------------------------------
        // Getters / Setters
        //--------------------------------------
        
        [Bindable("change")]
        [Bindable("valueCommit")]
        [Inspectable(category="General", defaultValue="0")]
        public function get selectedId():uint
        {
            if (this.selectedItem)
                return this.selectedItem.id;
            
            return 0;
        }
        
        public function set selectedId(value:uint):void
        {
            if (selectedId != value)
                this.selectedIndex = getIndexById(value);
        }
        
        public function get firstSelectedId():uint
        {
            if (selectedIndices && selectedIndices.length > 0)
                return m_collection.getItemAt(selectedIndices[0]).id;
            
            return 0;
        }
        
        public function get lastSelectedId():uint
        {
            if (selectedIndices && selectedIndices.length > 0)
                return m_collection.getItemAt(selectedIndices[selectedIndices.length - 1]).id;
            
            return 0;
        }
        
        public function get selectedIds():Vector.<uint>
        {
            var result:Vector.<uint> = new Vector.<uint>();
            if (selectedIndices) {
                var length:uint = selectedIndices.length;
                for (var i:uint = 0; i < length; i++)
                    result[i] = m_collection.getItemAt(selectedIndices[i]).id;
            }
            return result;
        }
        
        public function set selectedIds(value:Vector.<uint>):void
        {
            if (value) {
                var indices:Vector.<int> = new Vector.<int>();
                var length:uint = value.length;
                if (length > 1) {
                    for (var i:uint = 0; i < length; i++) {
                        var index:uint = getIndexById(value[i]);
                        if (index != -1)
                            indices[indices.length] = index;
                    }
                    this.selectedIndices = indices;
                } else if (length == 1)
                    this.selectedIndex = getIndexById(value[0]);
            }
        }
        
        public function get maxId():uint { return m_maxId; }
        public function get minId():uint { return m_minId; }
        public function get multipleSelected():Boolean { return (this.selectedIndices.length > 1); }
        public function get isEmpty():Boolean { return (m_collection.length == 0); }
        
        [Inspectable(category="General", defaultValue="true")]
        public function get contextMenuEnabled():Boolean { return m_contextMenuEnabled; }
        public function set contextMenuEnabled(value:Boolean):void
        {
            if (m_contextMenuEnabled != value)
                m_contextMenuEnabled = value;
        }
        
        public function get length():uint { return m_collection.length; }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function ListBase()
        {
            m_collection = new ArrayCollection();
            
            this.dataProvider = m_collection;
            this.addEventListener(FlexEvent.UPDATE_COMPLETE, updateCompleteHandler);
        }
        
        //--------------------------------------------------------------------------
        // METHODS
        //--------------------------------------------------------------------------
        
        //--------------------------------------
        // Public
        //--------------------------------------
        
        public function setList(list:Vector.<ListItem>):void
        {
            this.removeAll();
            
            if (list) {
                m_minId = uint.MAX_VALUE;
                m_maxId = 0;
                
                var length:uint = list.length;
                for (var i:uint = 0; i < length; i++) {
                    var item:ListItem = list[i];
                    var id:uint = item.id;
                    m_minId = id < m_minId ? id : m_minId;
                    m_maxId = id > m_maxId ? id : m_maxId;
                    m_collection.addItem(item);
                }
            }
        }
        
        public function updateList(list:Vector.<ListItem>):void
        {
            if (list && list.length > 0) {
                var length:uint = 0;
                var i:uint = 0;
                var dict:Dictionary = new Dictionary();
                
                length = list.length;
                for (i = 0; i < length; i++)
                    dict[list[i].id] = list[i];
                
                length = m_collection.length;
                for (i = 0; i < length; i++) {
                    var id:uint = m_collection.getItemAt(i).id;
                    if (dict[id] != undefined)
                        m_collection.setItemAt(dict[id], i);
                }
            }
        }
        
        public function removeSelectedIndices():void
        {
            var selectedIndices:Vector.<int> = this.selectedIndices;
            if (selectedIndices) {
                var length:uint = selectedIndices.length;
                if (length > 1)
                    selectedIndices.sort(Array.NUMERIC);
                
                for (var i:int = length - 1; i >= 0; i--)
                    m_collection.removeItemAt(selectedIndices[i]);
            }
        }
        
        public function removeAll():void
        {
            m_minId = 0;
            m_maxId = 0;
            m_collection.removeAll();
        }
        
        public function getIndexById(id:uint):int
        {
            var length:uint = m_collection.length;
            for (var i:uint = 0; i < length; i++) {
                if (m_collection.getItemAt(i).id == id)
                    return i;
            }
            return -1;
        }
        
        public function getIndexOf(item:ListItem):int
        {
            if (item)
                return m_collection.getItemIndex(item);
            
            return -1;
        }
        
        public function getObjectAt(index:int):ListItem
        {
            return ListItem( m_collection.getItemAt(index) );
        }
        
        public function rememberScroll():void
        {
            if (dataGroup && m_collection.length != 0) {
                var indicesInView:Vector.<int> = dataGroup.getItemIndicesInView();
                if (indicesInView && indicesInView.length != 0) {
                    var firstVisible:int = indicesInView[0];
                    var lastVisible:int = indicesInView[indicesInView.length - 1];
                    if (firstVisible < m_collection.length && lastVisible < m_collection.length) {
                        m_scrollSave = new ScrollPosition();
                        m_scrollSave.horizontalPosition = dataGroup.horizontalScrollPosition;
                        m_scrollSave.verticalPosition = dataGroup.verticalScrollPosition;
                        m_scrollSave.firstVisible = ListItem( m_collection.getItemAt(firstVisible) );
                        m_scrollSave.lastVisible = ListItem( m_collection.getItemAt(lastVisible) );
                    }
                } 
            }
        }
        
        public function ensureIdIsVisible(id:uint):void
        {
            m_ensureIdIsVisible = id;
        }
        
        public function refresh():void
        {
            ArrayCollection(m_collection).refresh();
        }
        
        //--------------------------------------
        // Private
        //--------------------------------------
        
        private function onEnsureIdIsVisible(id:uint):void
        {
            if (this.isEmpty) return;
            
            var firstVisible:ListItem;
            var lastVisible:ListItem;
            
            if (m_scrollSave) {
                firstVisible = m_scrollSave.firstVisible;
                lastVisible = m_scrollSave.lastVisible;
            } else {
                var indicesInView:Vector.<int> = dataGroup.getItemIndicesInView();
                if (indicesInView.length > 0) {
                    firstVisible = ListItem( m_collection.getItemAt(indicesInView[0]) );
                    lastVisible = ListItem( m_collection.getItemAt(indicesInView[indicesInView.length - 1]) );
                }
            }
            
            if ((firstVisible && (id - 1) < firstVisible.id) || (lastVisible && (id + 1) > lastVisible.id)) {
                var index:int = getIndexById(id);
                if (index != -1)
                    ensureIndexIsVisible(index);
            } else if (m_scrollSave) {
                dataGroup.horizontalScrollPosition = m_scrollSave.horizontalPosition;
                dataGroup.verticalScrollPosition = m_scrollSave.verticalPosition;
            }
            
            m_scrollSave = null;
        }
        
        //--------------------------------------
        // Event Handlers
        //--------------------------------------
        
        protected function updateCompleteHandler(event:FlexEvent):void
        {
            if (m_ensureIdIsVisible != uint.MAX_VALUE) {
                onEnsureIdIsVisible(m_ensureIdIsVisible);
                m_ensureIdIsVisible = uint.MAX_VALUE;
            }
        }
    }
}

import otlib.components.ListItem;

class ScrollPosition
{
    //--------------------------------------------------------------------------
    // PROPERTIES
    //--------------------------------------------------------------------------
    
    public var horizontalPosition:Number = 0;
    public var verticalPosition:Number = 0;
    public var firstVisible:ListItem;
    public var lastVisible:ListItem;
    
    //--------------------------------------------------------------------------
    // CONSTRUCTOR
    //--------------------------------------------------------------------------
    
    public function ScrollPosition()
    {
        
    }
}
