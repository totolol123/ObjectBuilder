///////////////////////////////////////////////////////////////////////////////////
//
//  Copyright (c) 2015 Nailson <https://github.com/Mignari/ObjectBuilder/graphs/contributors>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
///////////////////////////////////////////////////////////////////////////////////

package otlib.core
{
    import nail.errors.NullOrEmptyArgumentError;
    import nail.utils.StringUtil;
    import nail.utils.isNullOrEmpty;
    
    public final class Version
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        internal var m_value:uint;
        internal var m_description:String;
        internal var m_datSignature:uint;
        internal var m_sprSignature:uint;
        internal var m_otbVersion:uint;
        
        //--------------------------------------
        // Getters / Setters
        //--------------------------------------
        
        public function get value():uint { return m_value; }
        public function get description():String { return m_description; }
        public function get datSignature():uint { return m_datSignature; }
        public function get sprSignature():uint { return m_sprSignature; }
        public function get otbVersion():uint { return m_otbVersion; }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function Version(value:uint, description:String, datSignature:uint, sprSignature:uint, otbVersion:uint)
        {
            if (value < Version.MIN_VERSION)
                throw new ArgumentError(StringUtil.format("Invalid client version '{0}'.", value));
            
            if (isNullOrEmpty(description))
                throw new NullOrEmptyArgumentError("description");
            
            if (datSignature == 0)
                throw new ArgumentError("Invalid DAT signature.");
            
            if (sprSignature == 0)
                throw new ArgumentError("Invalid SPR signature.");
            
            m_value = value;
            m_description = description;
            m_datSignature = datSignature;
            m_sprSignature = sprSignature;
            m_otbVersion = otbVersion;
        }
        
        //----------------------------------------------------
        // METHODS
        //----------------------------------------------------
        
        //--------------------------------------
        // Public
        //--------------------------------------
        
        public function toString():String
        {
            return m_description;
        }
        
        public function equals(version:Version):Boolean
        {
            return(version &&
                   version.value == m_value &&
                   version.description == m_description &&
                   version.datSignature == m_datSignature &&
                   version.sprSignature == m_sprSignature &&
                   version.otbVersion == m_otbVersion);
        }
        
        public function clone():Version
        {
            return new Version(m_value, m_description, m_datSignature, m_sprSignature, m_otbVersion);
        }
        
        //--------------------------------------------------------------------------
        // STATIC
        //--------------------------------------------------------------------------
        
        public static const MIN_VERSION:uint = 710;
        public static const MAX_VERSION:uint = 1056;
        
        public static function valueToDescription(value:uint):String
        {
            return int(value / 100) + "." + (value % 100);
        }
        
        public static function create(value:uint, dat:uint, spr:uint, otb:uint):Version
        {
            return new Version(value, valueToDescription(value), dat, spr, otb);
        }
    }
}
