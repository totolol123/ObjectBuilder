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

package otlib.core
{
    import flash.events.EventDispatcher;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.utils.Dictionary;
    
    import nail.errors.FileNotFoundError;
    import nail.errors.NullArgumentError;
    import nail.errors.SingletonClassError;
    import nail.utils.StringUtil;
    import nail.utils.isNullOrEmpty;
    
    import otlib.events.StorageEvent;
    
    [Event(name="load", type="otlib.events.StorageEvent")]
    [Event(name="compile", type="otlib.events.StorageEvent")]
    [Event(name="change", type="otlib.events.StorageEvent")]
    [Event(name="unloading", type="otlib.events.StorageEvent")]
    [Event(name="unload", type="otlib.events.StorageEvent")]
    
    public class VersionStorage extends EventDispatcher implements IVersionStorage
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        private var m_file:File;
        private var m_versions:Dictionary;
        private var m_changed:Boolean;
        private var m_loaded:Boolean;
        
        //--------------------------------------
        // Getters / Setters
        //--------------------------------------
        
        public function get file():File { return m_file; }
        public function get changed():Boolean { return m_changed; }
        public function get loaded():Boolean { return m_loaded; }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function VersionStorage()
        {
            if (s_instance)
                throw new SingletonClassError(VersionStorage);
            
            s_instance = this;
            m_versions = new Dictionary();
        }
        
        //--------------------------------------------------------------------------
        // METHODS
        //--------------------------------------------------------------------------
        
        //--------------------------------------
        // Public
        //--------------------------------------
        
        public function load(file:File):Boolean
        {
            if (!file)
                throw new NullArgumentError("file");
            
            if (!file.exists)
                throw new FileNotFoundError(file);
            
            if (this.loaded) return true;
            
            var stream:FileStream = new FileStream();
            var xml:XML;
            
            try
            {
                stream.open(file, FileMode.READ);
                xml = XML( stream.readUTFBytes(stream.bytesAvailable) );
            }
            catch(error:Error)
            {
                stream.close();
                return false;
            }
            
            if (xml.localName() != "versions")
                throw new Error("Invalid versions XML.");
            
            for each (var versionXML:XML in xml.version) {
                
                if (!versionXML.hasOwnProperty("@value"))
                    throw new Error("Version.unserialize: Missing 'value' attribute.");
                
                if (!versionXML.hasOwnProperty("@string"))
                    throw new Error("Version.unserialize: Missing 'string' attribute.");
                
                if (!versionXML.hasOwnProperty("@dat"))
                    throw new Error("Version.unserialize: Missing 'dat' attribute.");
                
                if (!versionXML.hasOwnProperty("@spr"))
                    throw new Error("Version.unserialize: Missing 'spr' attribute.");
                
                if (!versionXML.hasOwnProperty("@otb"))
                    throw new Error("Version.unserialize: Missing 'otb' attribute.");
                
                var value:uint = uint(versionXML.@value);
                var description:String = String(versionXML.@string);
                var dat:uint = uint(StringUtil.format("0x{0}", versionXML.@dat));
                var spr:uint = uint(StringUtil.format("0x{0}", versionXML.@spr));
                var otb:uint = uint(versionXML.@otb);
                m_versions[description] = new Version(value, description, dat, spr, otb);
            }
            
            m_file = file;
            m_changed = false;
            m_loaded = true;
            
            if (hasEventListener(StorageEvent.LOAD))
                dispatchEvent(new StorageEvent(StorageEvent.LOAD));
            
            return m_loaded;
        }
        
        public function addVersion(version:Version):Boolean
        {
            if (!version)
                throw new NullArgumentError("version");
            
            if (getBySignatures(version.datSignature, version.sprSignature) != null)
                return false;
            
            var desc:String = Version.valueToDescription(version.value);
            var description:String = desc;
            var index:uint = 1;
            while (m_versions[description] !== undefined)
                description = desc + 'v' + (++index);
            
            version.m_description = description;
            m_versions[description] = version;
            
            m_changed = true;
            if (hasEventListener(StorageEvent.CHANGE))
                dispatchEvent(new StorageEvent(StorageEvent.CHANGE));
            
            return true;
        }
        
        public function removeVersion(version:Version):Boolean
        {
            if (!version)
                throw new NullArgumentError("version");
            
            var removed:Boolean = false;
            for each (var v:Version in m_versions) {
                if (v.equals(version)) {
                    delete m_versions[v.description];
                    removed = true;
                }
            }
            
            m_changed = (m_changed || removed);
            if (hasEventListener(StorageEvent.CHANGE))
                dispatchEvent(new StorageEvent(StorageEvent.CHANGE));
            
            return removed;
        }
        
        public function save():Boolean
        {
            if (!m_loaded || !m_changed)
                return false;
            
            var xml:XML = <versions/>;
            var list:Array = getList();
            var length:uint = list.length;
            
            for (var i:uint = 0; i < length; i++)
                xml.appendChild(serializeVersion(list[i]));
            
            var xmlStr:String = '<?xml version="1.0" encoding="utf-8"?>' +
                File.lineEnding +
                xml.toXMLString();
            
            try
            {
                var stream:FileStream = new FileStream();
                stream.open(m_file, FileMode.WRITE);
                stream.writeUTFBytes(xmlStr);
                stream.close();
            }
            catch(error:Error)
            {
                return false;
            }
            
            m_changed = false;
            if (hasEventListener(StorageEvent.COMPILE))
                dispatchEvent(new StorageEvent(StorageEvent.COMPILE));
            
            return true;
        }
        
        public function getList():Array
        {
            var list:Array = [];
            
            for each (var version:Version in m_versions)
                list[list.length] = version;
            
            if (list.length > 1)
                list.sortOn("value", Array.NUMERIC | Array.DESCENDING);
            
            return list;
        }
        
        public function getByValue(value:uint):Vector.<Version>
        {
            var list:Vector.<Version> = new Vector.<Version>();
            for each (var version:Version in m_versions) {
                if (version.value == value)
                    list[list.length] = version;
            }
            return list;
        }
        
        public function getByDescription(description:String):Version
        {
            if (!isNullOrEmpty(description)) {
                if (m_versions[description] !== undefined)
                    return m_versions[description];
            }
            return null;
        }
        
        public function getBySignatures(dat:uint, spr:uint):Version
        {
            if (dat != 0 && spr != 0) {
                for each (var version:Version in m_versions) {
                    if (version.sprSignature == spr && version.datSignature == dat)
                        return version;
                }
            }
            return null;
        }
        
        public function getByOtbVersion(otb:uint):Vector.<Version>
        {
            var list:Vector.<Version> = new Vector.<Version>();
            for each (var version:Version in m_versions) {
                if (version.otbVersion == otb)
                    list[list.length] = version;
            }
            return list;
        }
        
        public function unload():void
        {
            if (!m_loaded) return;
            
            var event:StorageEvent = new StorageEvent(StorageEvent.UNLOADING, false, true);
            dispatchEvent(event);
            if (event.isDefaultPrevented()) return;
            
            m_file = null;
            m_versions = new Dictionary();
            m_changed = false;
            m_loaded = false;
            
            if (hasEventListener(StorageEvent.UNLOAD))
                dispatchEvent(new StorageEvent(StorageEvent.UNLOAD));
        }
        
        //--------------------------------------
        // Private
        //--------------------------------------
        
        private function serializeVersion(version:Version):XML
        {
            var xml:XML = <version/>;
            xml.@value = version.value;
            xml.@string = version.description;
            xml.@dat = version.datSignature.toString(16).toUpperCase();
            xml.@spr = version.sprSignature.toString(16).toUpperCase();
            xml.@otb = version.otbVersion;
            return xml;
        }
        
        //--------------------------------------------------------------------------
        // STATIC
        //--------------------------------------------------------------------------
        
        private static var s_instance:IVersionStorage;
        public static function getInstance():IVersionStorage
        {
            if (!s_instance)
                new VersionStorage();
            
            return s_instance;
        }
    }
}

