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

package ob.settings
{
    import flash.filesystem.File;
    
    import mx.core.FlexGlobals;
    
    import nail.image.ImageFormat;
    import nail.utils.FileUtil;
    import nail.utils.PathUtil;
    import nail.utils.isNullOrEmpty;
    
    import ob.core.IObjectBuilder;
    
    import otlib.core.IVersionStorage;
    import otlib.core.Version;
    import otlib.obd.OBDVersions;
    import otlib.settings.Settings;
    import otlib.utils.OTFormat;
    
    public class ObjectBuilderSettings extends Settings
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        public var lastDirectory:String;
        public var lastIODirectory:String;
        public var autosaveThingChanges:Boolean;
        public var loadFilesOnStartup:Boolean;
        public var maximized:Boolean = true;
        public var previewContainerWidth:Number = 0;
        public var thingListContainerWidth:Number = 0;
        public var spritesContainerWidth:Number = 0;
        public var showPreviewPanel:Boolean = true;
        public var showThingsPanel:Boolean = true;
        public var showSpritesPanel:Boolean = true;
        public var language:String = "en_US";
        public var findWindowWidth:Number = 0;
        public var findWindowHeight:Number = 0;
        public var objectViewerWidth:Number = 0;
        public var objectViewerHeight:Number = 0;
        public var objectViewerMaximized:Boolean;
        public var objectsListAmount:Number = 100;
        public var spritesListAmount:Number = 100;
        public var exportWithTransparentBackground:Boolean = false;
        public var jpegQuality:Number = 100;
        public var extendedAlwaysSelected:Boolean;
        public var transparencyAlwaysSelected:Boolean;
        public var improvedAnimationsAlwaysSelected:Boolean;
        
        // import / export
        public var exportThingFormat:String;
        public var exportOBDVersion:uint = OBDVersions.OBD_VERSION_2;
        public var exportSpriteFormat:String;
        public var exportObjectProperties:Boolean;
        
        // versions window
        public var versionsWindowMaximized:Boolean = true;
        public var versionsWindowWidth:Number = 0;
        public var versionsWindowHeight:Number = 0;
        
        // default settings for startup
        public var datSignature:int;
        public var sprSignature:int;
        public var extended:Boolean;
        public var transparency:Boolean;
        public var improvedAnimations:Boolean;
        public var datPath:String;
        public var sprPath:String;
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function ObjectBuilderSettings()
        {
        }
        
        //--------------------------------------------------------------------------
        // METHODS
        //--------------------------------------------------------------------------
        
        //--------------------------------------
        // Public
        //--------------------------------------
        
        public function getClientDirectory():File
        {
            var file:File = PathUtil.toFile(datPath);
            return (file != null) ? FileUtil.getDirectory(file) : null;
        }
        
        public function getIODirectory():File
        {
            return PathUtil.toFile(this.lastIODirectory) || File.documentsDirectory;
        }
        
        public function setIODirectory(file:File):void
        {
            if (file)
                this.lastIODirectory = FileUtil.getDirectory(file).nativePath;
        }
        
        public function getExportThingFormat():String
        {
            if (!isNullOrEmpty(exportThingFormat)) {
                if (ImageFormat.hasImageFormat(exportThingFormat) || exportThingFormat == OTFormat.OBD) {
                    return exportThingFormat;
                }
            }
            return null;
        }
        
        public function setExportThingFormat(format:String):void
        {
            format = format ? format.toLowerCase() : "";
            this.exportThingFormat = format;
        }
        
        public function getExportThingVersion():Version
        {
            var versionStorage:IVersionStorage = IObjectBuilder(FlexGlobals.topLevelApplication).versionStorage;
            return versionStorage.getBySignatures(datSignature, sprSignature);
        }
        
        public function setExportThingVersion(version:Version):void
        {
            this.datSignature = !version ? 0 : version.datSignature;
            this.sprSignature = !version ? 0 : version.sprSignature;
        }
        
        public function getExportSpriteFormat():String
        {
            if (ImageFormat.hasImageFormat(exportSpriteFormat)) {
                return exportSpriteFormat;
            }
            return null;
        }
        
        public function setExportSpriteFormat(format:String):void
        {
            format = !format ? "" : format.toLowerCase();
            this.exportSpriteFormat = format;
        }
        
        public function getLanguage():Array
        {
            if (isNullOrEmpty(language) || language == "null")
                return ["en_US"];
                
            return [language];
        }
    }
}
