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

package ob.core
{
    import flash.display.BitmapData;
    import flash.display.Sprite;
    import flash.events.ErrorEvent;
    import flash.events.Event;
    import flash.filesystem.File;
    import flash.geom.Rectangle;
    import flash.net.registerClassAlias;
    import flash.system.Worker;
    import flash.utils.ByteArray;
    
    import mx.resources.ResourceManager;
    
    import nail.commands.Command;
    import nail.commands.Communicator;
    import nail.commands.ICommunicator;
    import nail.errors.NullArgumentError;
    import nail.errors.NullOrEmptyArgumentError;
    import nail.image.ImageCodec;
    import nail.image.ImageFormat;
    import nail.logging.Log;
    import nail.utils.FileUtil;
    import nail.utils.SaveHelper;
    import nail.utils.StringUtil;
    import nail.utils.VectorUtils;
    import nail.utils.isNullOrEmpty;
    
    import ob.commands.CompileProjectAsCommand;
    import ob.commands.CompileProjectCommand;
    import ob.commands.CreateNewProjectCommand;
    import ob.commands.FindResultCommand;
    import ob.commands.HideProgressBarCommand;
    import ob.commands.LoadProjectCommand;
    import ob.commands.LoadVersionsCommand;
    import ob.commands.NeedToReloadCommand;
    import ob.commands.ProgressBarID;
    import ob.commands.ProgressCommand;
    import ob.commands.SetClientInfoCommand;
    import ob.commands.SettingsCommand;
    import ob.commands.ShowProgressBarCommand;
    import ob.commands.UnloadProjectCommand;
    import ob.commands.sprites.ExportSpritesCommand;
    import ob.commands.sprites.FindSpritesCommand;
    import ob.commands.sprites.GetSpriteListCommand;
    import ob.commands.sprites.ImportSpritesCommand;
    import ob.commands.sprites.ImportSpritesFromFileCommand;
    import ob.commands.sprites.NewSpriteCommand;
    import ob.commands.sprites.OptimizeSpritesCommand;
    import ob.commands.sprites.OptimizeSpritesResultCommand;
    import ob.commands.sprites.RemoveSpritesCommand;
    import ob.commands.sprites.ReplaceSpritesCommand;
    import ob.commands.sprites.ReplaceSpritesFromFilesCommand;
    import ob.commands.sprites.SetSpriteListCommand;
    import ob.commands.things.DuplicateThingCommand;
    import ob.commands.things.ExportThingCommand;
    import ob.commands.things.FindThingCommand;
    import ob.commands.things.GetThingDataCommand;
    import ob.commands.things.GetThingListCommand;
    import ob.commands.things.ImportThingsCommand;
    import ob.commands.things.ImportThingsFromFilesCommand;
    import ob.commands.things.NewThingCommand;
    import ob.commands.things.RemoveThingCommand;
    import ob.commands.things.ReplaceThingsCommand;
    import ob.commands.things.ReplaceThingsFromFilesCommand;
    import ob.commands.things.SetThingDataCommand;
    import ob.commands.things.SetThingListCommand;
    import ob.commands.things.UpdateThingCommand;
    import ob.settings.ObjectBuilderSettings;
    import ob.utils.ObUtils;
    import ob.utils.SpritesFinder;
    import ob.utils.SpritesOptimizer;
    
    import otlib.components.ListItem;
    import otlib.core.IVersionStorage;
    import otlib.core.Version;
    import otlib.core.VersionStorage;
    import otlib.events.ProgressEvent;
    import otlib.events.StorageEvent;
    import otlib.loaders.PathHelper;
    import otlib.loaders.SpriteDataLoader;
    import otlib.loaders.ThingDataLoader;
    import otlib.obd.OBDEncoder;
    import otlib.obd.OBDVersions;
    import otlib.otml.OTMLDocument;
    import otlib.otml.OTMLNode;
    import otlib.resources.Resources;
    import otlib.sprites.Sprite;
    import otlib.sprites.SpriteData;
    import otlib.sprites.SpriteSheet;
    import otlib.sprites.SpriteStorage;
    import otlib.things.Animator;
    import otlib.things.FrameDuration;
    import otlib.things.ThingCategory;
    import otlib.things.ThingData;
    import otlib.things.ThingProperty;
    import otlib.things.ThingType;
    import otlib.things.ThingTypeStorage;
    import otlib.utils.ChangeResult;
    import otlib.utils.ClientInfo;
    import otlib.utils.MinMaxValues;
    import otlib.utils.OTFI;
    import otlib.utils.OTFormat;
    
    [ResourceBundle("strings")]
    
    public class ObjectBuilderWorker extends flash.display.Sprite implements ICommunicator
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        private var m_communicator:ICommunicator;
        private var m_versions:IVersionStorage;
        private var m_things:ThingTypeStorage;
        private var m_sprites:SpriteStorage;
        private var m_datFile:File;
        private var m_sprFile:File;
        private var m_version:Version;
        private var m_extended:Boolean;
        private var m_transparency:Boolean;
        private var m_improvedAnimations:Boolean;
        private var m_errorMessage:String;
        private var m_compiled:Boolean;
        private var m_isTemporary:Boolean;
        private var m_thingListAmount:uint;
        private var m_spriteListAmount:uint;
        private var m_thingCategory:String;
        private var m_thingListMinMax:MinMaxValues;
        private var m_spriteListMinMax:MinMaxValues;
        
        //--------------------------------------
        // Getters / Setters
        //--------------------------------------
        
        public function get worker():Worker { return m_communicator.worker; }
        public function get running():Boolean { return m_communicator.running; }
        public function get background():Boolean { return m_communicator.background; }
        public function get applicationDescriptor():XML { return m_communicator.applicationDescriptor; }
        
        public function get clientChanged():Boolean
        {
            return ((m_things && m_things.changed) || (m_sprites && m_sprites.changed));
        }
        
        public function get clientIsTemporary():Boolean
        {
            return (m_things && m_things.isTemporary && m_sprites && m_sprites.isTemporary);
        }
        
        public function get clientLoaded():Boolean
        {
            return (m_things && m_things.loaded && m_sprites && m_sprites.loaded);
        }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function ObjectBuilderWorker()
        {
            super();
            
            Resources.manager = ResourceManager.getInstance();
            
            m_communicator = new Communicator();
            m_versions = VersionStorage.getInstance();
            m_thingListAmount = 100;
            m_spriteListAmount = 100;
            m_thingListMinMax = new MinMaxValues();
            m_spriteListMinMax = new MinMaxValues();
            
            register();
        }
        
        //--------------------------------------------------------------------------
        // METHODS
        //--------------------------------------------------------------------------
        
        //--------------------------------------
        // Public
        //--------------------------------------
        
        public function registerCallback(commandClass:Class, callback:Function):void
        {
            m_communicator.registerCallback(commandClass, callback);
        }
        
        public function unregisterCallback(commandClass:Class, callback:Function):void
        {
            m_communicator.unregisterCallback(commandClass, callback);
        }
        
        public function sendCommand(command:Command):void
        {
            m_communicator.sendCommand(command);
        }
        
        public function start():void
        {
            //unused
        }
        
        public function onGetThing(id:uint, category:String):void
        {
            sendThingData(id, category);
        }
        
        public function onCompile():void
        {
            this.onCompileAs(m_datFile.nativePath,
                            m_sprFile.nativePath,
                            m_version.datSignature,
                            m_version.sprSignature,
                            m_extended,
                            m_transparency,
                            m_improvedAnimations);
        }
        
        public function setSelectedThingIds(value:Vector.<uint>, category:String):void
        {
            if (value && value.length > 0) {
                if (value.length > 1) value.sort(Array.NUMERIC | Array.DESCENDING);
                var max:uint = m_things.getMaxId(category);
                if (value[0] > max) {
                    value = Vector.<uint>([max]);
                }
                this.onGetThing(value[0], category);
                this.sendThingList(value, category);
            }
        }
        
        public function setSelectedSpriteIds(value:Vector.<uint>):void
        {
            if (value && value.length > 0) {
                if (value.length > 1) value.sort(Array.NUMERIC | Array.DESCENDING);
                if (value[0] > m_sprites.spritesCount) {
                    value = Vector.<uint>([m_sprites.spritesCount]);
                }
                this.sendSpriteList(value);
            }
        }
        
        //--------------------------------------
        // Override Protected
        //--------------------------------------
        
        public function register():void
        {
            // Register classes.
            registerClassAlias("Animator", Animator);
            registerClassAlias("ByteArray", ByteArray);
            registerClassAlias("ClientInfo", ClientInfo);
            registerClassAlias("File", File);
            registerClassAlias("FrameDuration", FrameDuration);
            registerClassAlias("ListItem", ListItem);
            registerClassAlias("ObjectBuilderSettings", ObjectBuilderSettings);
            registerClassAlias("PathHelper", PathHelper);
            registerClassAlias("SpriteData", SpriteData);
            registerClassAlias("ThingData", ThingData);
            registerClassAlias("ThingProperty", ThingProperty);
            registerClassAlias("ThingType", ThingType);
            
            registerCallback(SettingsCommand, onSettings);
            
            registerCallback(LoadVersionsCommand, onLoadClientVersions);
            
            // File commands
            registerCallback(CreateNewProjectCommand, onCreateNewFiles);
            registerCallback(LoadProjectCommand, onLoadFiles);
            registerCallback(CompileProjectCommand, onCompile);
            registerCallback(CompileProjectAsCommand, onCompileAs);
            registerCallback(UnloadProjectCommand, onUnloadFiles);
            
            // Thing commands
            registerCallback(NewThingCommand, onNewThing);
            registerCallback(UpdateThingCommand, onUpdateThing);
            registerCallback(ImportThingsCommand, onImportThings);
            registerCallback(ImportThingsFromFilesCommand, onImportThingsFromFiles);
            registerCallback(ExportThingCommand, onExportThing);
            registerCallback(ReplaceThingsCommand, onReplaceThings);
            registerCallback(ReplaceThingsFromFilesCommand, onReplaceThingsFromFiles);
            registerCallback(DuplicateThingCommand, onDuplicateThing);
            registerCallback(RemoveThingCommand, onRemoveThings);
            registerCallback(GetThingDataCommand, onGetThing);
            registerCallback(GetThingListCommand, onGetThingList);
            registerCallback(FindThingCommand, onFindThing);
            
            // Sprite commands
            registerCallback(NewSpriteCommand, onNewSprite);
            registerCallback(ImportSpritesCommand, onAddSprites);
            registerCallback(ImportSpritesFromFileCommand, onImportSpritesFromFiles);
            registerCallback(ExportSpritesCommand, onExportSprites);
            registerCallback(ReplaceSpritesCommand, onReplaceSprites);
            registerCallback(ReplaceSpritesFromFilesCommand, onReplaceSpritesFromFiles);
            registerCallback(RemoveSpritesCommand, onRemoveSprites);
            registerCallback(GetSpriteListCommand, onGetSpriteList);
            registerCallback(FindSpritesCommand, onFindSprites);
            registerCallback(OptimizeSpritesCommand, onOptimizeSprites);
            
            // General commands
            registerCallback(NeedToReloadCommand, onNeedToReload);
        }
        
        //--------------------------------------
        // Private
        //--------------------------------------
        
        private function onLoadClientVersions(path:String):void
        {
            if (isNullOrEmpty(path))
                throw new NullOrEmptyArgumentError("path");
            
            m_versions.unload();
            m_versions.load(new File(path));
        }
        
        private function onSettings(settings:ObjectBuilderSettings):void
        {
            if (isNullOrEmpty(settings))
                throw new NullOrEmptyArgumentError("settings");
            
            Resources.locale = settings.getLanguage()[0];
            m_thingListAmount = settings.objectsListAmount;
            m_spriteListAmount = settings.spritesListAmount;
        }
        
        private function onCreateNewFiles(datSignature:uint,
                                          sprSignature:uint,
                                          extended:Boolean,
                                          transparency:Boolean,
                                          improvedAninations:Boolean):void
        {
            var clientVersion:Version = m_versions.getBySignatures(datSignature, sprSignature);
            if (!clientVersion)
                throw new ArgumentError(StringUtil.format("Invalid client signatures. Dat=0x{0}, Spr=0x{1}", datSignature.toString(16), sprSignature.toString(16)));
            
            this.onUnloadFiles();
            
            m_version = clientVersion;
            m_extended = (extended || m_version.value >= 960);
            m_transparency = transparency;
            m_improvedAnimations = (improvedAninations || m_version.value >= 1050);
            
            this.createStorage();
            
            // Create things.
            m_things.createNew(m_version, m_extended, m_improvedAnimations);
            
            // Create sprites.
            m_sprites.createNew(m_version, m_extended, m_transparency)
            
            // Update preview.
            var thing:ThingType = m_things.getItemType(ThingTypeStorage.MIN_ITEM_ID);
            this.onGetThing(thing.id, thing.category);
            
            // Send sprites.
            this.sendSpriteList(Vector.<uint>([1]));
        }
        
        private function createStorage():void
        {
            m_things = new ThingTypeStorage();
            m_things.addEventListener(StorageEvent.LOAD, storageLoadHandler);
            m_things.addEventListener(StorageEvent.CHANGE, storageChangeHandler);
            m_things.addEventListener(ProgressEvent.PROGRESS, thingsProgressHandler);
            m_things.addEventListener(ErrorEvent.ERROR, thingsErrorHandler);
            
            m_sprites = new SpriteStorage();
            m_sprites.addEventListener(StorageEvent.LOAD, storageLoadHandler);
            m_sprites.addEventListener(StorageEvent.CHANGE, storageChangeHandler);
            m_sprites.addEventListener(ProgressEvent.PROGRESS, spritesProgressHandler);
            m_sprites.addEventListener(ErrorEvent.ERROR, spritesErrorHandler);
        }
        
        private function onLoadFiles(datPath:String,
                                     sprPath:String,
                                     datSignature:uint,
                                     sprSignature:uint,
                                     extended:Boolean,
                                     transparency:Boolean,
                                     improvedAnimations:Boolean):void
        {
            if (isNullOrEmpty(datPath))
                throw new NullOrEmptyArgumentError("datPath");
            
            if (isNullOrEmpty(sprPath))
                throw new NullOrEmptyArgumentError("sprPath");
            
            var clientVersion:Version = m_versions.getBySignatures(datSignature, sprSignature);
            if (!clientVersion)
                throw new ArgumentError(StringUtil.format("Invalid client signatures. Dat=0x{0}, Spr=0x{1}", datSignature.toString(16), sprSignature.toString(16)));
            
            this.onUnloadFiles();
            
            m_datFile = new File(datPath);
            m_sprFile = new File(sprPath);
            m_version = clientVersion;
            m_extended = (extended || m_version.value >= 960);
            m_transparency = transparency;
            m_improvedAnimations = (improvedAnimations || m_version.value >= 1050);
            
            var title:String = Resources.getString("loading");
            sendCommand(new ShowProgressBarCommand(ProgressBarID.DAT_SPR, title));
            
            createStorage();
            
            m_things.load(m_datFile, m_version, m_extended, m_improvedAnimations);
            m_sprites.load(m_sprFile, m_version, m_extended, m_transparency);
        }
        
        private function onCompileAs(datPath:String,
                                     sprPath:String,
                                     datSignature:uint,
                                     sprSignature:uint,
                                     extended:Boolean,
                                     transparency:Boolean,
                                     improvedAnimations:Boolean):void
        {
            if (isNullOrEmpty(datPath))
                throw new NullOrEmptyArgumentError("datPath");
            
            if (isNullOrEmpty(sprPath))
                throw new NullOrEmptyArgumentError("sprPath");
            
            var clientVersion:Version = m_versions.getBySignatures(datSignature, sprSignature);
            if (!clientVersion)
                throw new ArgumentError(StringUtil.format("Invalid client signatures. Dat=0x{0}, Spr=0x{1}", datSignature.toString(16), sprSignature.toString(16)));
            
            if (!m_things || !m_things.loaded)
                throw new Error(Resources.getString("metadataNotLoaded"));
            
            if (!m_sprites || !m_sprites.loaded)
                throw new Error(Resources.getString("spritesNotLoaded"));
            
            var dat:File = new File(datPath);
            var spr:File = new File(sprPath);
            var structureChanged:Boolean = (m_extended != extended ||
                                            m_transparency != transparency ||
                                            m_improvedAnimations != improvedAnimations);
            var title:String = Resources.getString("compiling");
            
            sendCommand(new ShowProgressBarCommand(ProgressBarID.DAT_SPR, title));
            
            if (!m_things.compile(dat, clientVersion, extended, improvedAnimations) ||
                !m_sprites.compile(spr, clientVersion, extended, transparency)) {
                return;
            }
            
            // Save .otfi file
            var dir:File = FileUtil.getDirectory(dat);
            var otfiFile:File = dir.resolvePath(FileUtil.getName(dat) + "." + OTFormat.OTFI);
            var otfi:OTFI = new OTFI(extended, transparency, improvedAnimations);
            otfi.save(otfiFile);
            
            clientCompileComplete();
            
            if (!m_datFile || !m_sprFile) {
                m_datFile = dat;
                m_sprFile = spr;
            }
            
            // If extended or alpha channel was changed need to reload.
            if (FileUtil.equals(dat, m_datFile) && FileUtil.equals(spr, m_sprFile)) {
                if (structureChanged)
                    sendCommand(new NeedToReloadCommand(extended, transparency, improvedAnimations));
                else
                    sendClientInfo();
            }
        }
        
        private function onUnloadFiles():void
        {
            if (m_things) {
                m_things.unload();
                m_things.removeEventListener(StorageEvent.LOAD, storageLoadHandler);
                m_things.removeEventListener(StorageEvent.CHANGE, storageChangeHandler);
                m_things.removeEventListener(ProgressEvent.PROGRESS, thingsProgressHandler);
                m_things.removeEventListener(ErrorEvent.ERROR, thingsErrorHandler);
                m_things = null;
            }
            
            if (m_sprites) {
                m_sprites.unload();
                m_sprites.removeEventListener(StorageEvent.LOAD, storageLoadHandler);
                m_sprites.removeEventListener(StorageEvent.CHANGE, storageChangeHandler);
                m_sprites.removeEventListener(ProgressEvent.PROGRESS, spritesProgressHandler);
                m_sprites.removeEventListener(ErrorEvent.ERROR, spritesErrorHandler);
                m_sprites = null;
            }
            
            m_datFile = null;
            m_sprFile = null;
            m_version = null;
            m_extended = false;
            m_transparency = false;
            m_errorMessage = null;
        }
        
        private function onNewThing(category:String):void
        {
            if (!ThingCategory.getCategory(category)) {
                throw new Error(Resources.getString("invalidCategory"));
            }
            
            //============================================================================
            // Add thing
            
            var thing:ThingType = ThingType.create(0, category);
            var result:ChangeResult = m_things.addThing(thing, category);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            //============================================================================
            // Send changes
            
            // Send thing to preview.
            onGetThing(thing.id, category);
            
            // Send message to log.
            var message:String = Resources.getString(
                "logAdded",
                toLocale(category),
                thing.id);
            
            Log.info(message);
        }
        
        private function onUpdateThing(thingData:ThingData, replaceSprites:Boolean):void
        {
            if (!thingData) {
                throw new NullArgumentError("thingData");
            }
            
            var result:ChangeResult;
            var thing:ThingType = thingData.thing;
            
            if (!m_things.hasThingType(thing.category, thing.id)) {
                throw new Error(Resources.getString(
                    "thingNotFound",
                    toLocale(thing.category),
                    thing.id));
            }
            
            //============================================================================
            // Update sprites
            
            var sprites:Vector.<SpriteData> = thingData.sprites;
            var length:uint = sprites.length;
            var spritesIds:Vector.<uint> = new Vector.<uint>();
            var addedSpriteList:Array = [];
            var currentThing:ThingType = m_things.getThingType(thing.id, thing.category);
            
            for (var i:uint = 0; i < length; i++) {
                var spriteData:SpriteData = sprites[i];
                var id:uint = thing.spriteIDs[i];
                
                if (id == uint.MAX_VALUE) {
                    if (spriteData.isEmpty()) {
                        thing.spriteIDs[i] = 0;
                    } else {
                        
                        if (replaceSprites) {
                            result = m_sprites.replaceSprite(currentThing.spriteIDs[i], spriteData.pixels);
                        } else {
                            result = m_sprites.addSprite(spriteData.pixels);
                        }
                        
                        if (!result.done) {
                            Log.error(result.message);
                            return;
                        }
                        
                        spriteData = result.list[0];
                        thing.spriteIDs[i] = spriteData.id;
                        spritesIds[spritesIds.length] = spriteData.id;
                        addedSpriteList[addedSpriteList.length] = spriteData;
                    }
                } else {
                    if (!m_sprites.hasSpriteId(id)) {
                        Log.error(Resources.getString("spriteNotFound", id));
                        return;
                    }
                }
            }
            
            //============================================================================
            // Update thing
            
            result = m_things.replaceThing(thing, thing.category, thing.id);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            //============================================================================
            // Send changes
            
            var message:String;
            
            // Sprites change message
            if (spritesIds.length > 0) {
                message = Resources.getString(
                    replaceSprites ? "logReplaced" : "logAdded",
                    toLocale("sprite", spritesIds.length > 1),
                    spritesIds);
                
                Log.info(message);
                
                this.setSelectedSpriteIds(spritesIds);
            }
            
            // Thing change message
            onGetThing(thingData.id, thingData.category);
            
            sendThingList(Vector.<uint>([ thingData.id ]), thingData.category);
            
            message = Resources.getString(
                "logChanged",
                toLocale(thing.category),
                thing.id);
            
            Log.info(message);
        }
        
        private function onExportThing(list:Vector.<PathHelper>,
                                       category:String,
                                       obdVersion:uint,
                                       datSignature:uint,
                                       sprSignature:uint,
                                       exportObjectProperties:Boolean,
                                       transparentBackground:Boolean,
                                       jpegQuality:uint):void
        {
            if (!list)
                throw new NullArgumentError("list");
            
            if (!ThingCategory.getCategory(category))
                throw new ArgumentError(Resources.getString("invalidCategory"));
            
            var clientVersion:Version = m_versions.getBySignatures(datSignature, sprSignature);
            if (!clientVersion)
                throw new ArgumentError(StringUtil.format("Invalid client signatures. Dat=0x{0}, Spr=0x{1}", datSignature.toString(16), sprSignature.toString(16)));
            
            var length:uint = list.length;
            if (length == 0) return;
            
            //============================================================================
            // Export things
            
            sendCommand(new ShowProgressBarCommand(ProgressBarID.DEFAULT, Resources.getString("exportingObjects")));
            
            var encoder:OBDEncoder = new OBDEncoder();
            var helper:SaveHelper = new SaveHelper();
            var backgoundColor:uint = (m_transparency || transparentBackground) ? 0x00FF00FF : 0xFFFF00FF;
            var bytes:ByteArray;
            var spriteSheet:SpriteSheet;
            
            for (var i:uint = 0; i < length; i++) {
                var pathHelper:PathHelper = list[i];
                var thingData:ThingData = getThingData(pathHelper.id, category, obdVersion, clientVersion.value);
                var file:File = new File(pathHelper.nativePath);
                var name:String = FileUtil.getName(file);
                var format:String = file.extension;
                
                if (ImageFormat.hasImageFormat(format)) {
                    spriteSheet = thingData.getSpriteSheet(backgoundColor);
                    bytes = ImageCodec.encode(spriteSheet, format, jpegQuality);
                    if (exportObjectProperties) {
                        var node:OTMLNode = thingData.serialize();
                        var spriteSheetNode:OTMLNode = spriteSheet.serialize();
                        spriteSheetNode.writeAt("image-source", file.name, 0);
                        node.addChild(spriteSheetNode);
                        var doc:OTMLDocument = OTMLDocument.create();
                        doc.addChild(node);
                        helper.addFile(doc.toOTMLString(), name, OTFormat.OBI, file);
                    }
                } else if (format == OTFormat.OBD) {
                    bytes = encoder.encode(thingData);
                }
                helper.addFile(bytes, name, format, file);
            }
            helper.addEventListener(flash.events.ProgressEvent.PROGRESS, progressHandler);
            helper.addEventListener(Event.COMPLETE, completeHandler);
            helper.save();
            
            function progressHandler(event:flash.events.ProgressEvent):void
            {
                sendCommand(new ProgressCommand(ProgressBarID.DEFAULT, event.bytesLoaded, event.bytesTotal));
            }
            
            function completeHandler(event:Event):void
            {
                sendCommand(new HideProgressBarCommand(ProgressBarID.DEFAULT));
            }
        }
        
        private function onReplaceThings(list:Vector.<ThingData>):void
        {
            if (!list) {
                throw new NullArgumentError("list");
            }
            
            var length:uint = list.length;
            if (length == 0) return;
            
            //============================================================================
            // Add sprites
            
            var result:ChangeResult;
            var spritesIds:Vector.<uint> = new Vector.<uint>();
            for (var i:uint = 0; i < length; i++) {
                var thing:ThingType = list[i].thing;
                var sprites:Vector.<SpriteData> = list[i].sprites;
                var len:uint = sprites.length;
                
                for (var k:uint = 0; k < len; k++) {
                    var spriteData:SpriteData = sprites[k];
                    var id:uint = spriteData.id;
                    if (spriteData.isEmpty()) {
                        id = 0;
                    } else if (!m_sprites.hasSpriteId(id) || !m_sprites.compare(id, spriteData.pixels)) {
                        result = m_sprites.addSprite(spriteData.pixels);
                        if (!result.done) {
                            Log.error(result.message);
                            return;
                        }
                        id = m_sprites.spritesCount;
                        spritesIds[spritesIds.length] = id;
                    }
                    thing.spriteIDs[k] = id;
                }
            }
            
            //============================================================================
            // Replace things
            
            var thingsToReplace:Vector.<ThingType> = new Vector.<ThingType>(length, true);
            var thingsIds:Vector.<uint> = new Vector.<uint>(length, true);
            for (i = 0; i < length; i++) {
                thingsToReplace[i] = list[i].thing;
                thingsIds[i] = list[i].id;
            }
            result = m_things.replaceThings(thingsToReplace);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            //============================================================================
            // Send changes
            
            var message:String;
            
            // Added sprites message
            if (spritesIds.length > 0)
            {
                this.sendSpriteList(Vector.<uint>([m_sprites.spritesCount]));
                
                message = Resources.getString(
                    "logAdded",
                    toLocale("sprite", spritesIds.length > 1),
                    spritesIds);
                
                Log.info(message);
            }
            
            var category:String = list[0].thing.category;
            this.setSelectedThingIds(thingsIds, category);
            
            message = Resources.getString(
                "logReplaced",
                toLocale(category, thingsIds.length > 1),
                thingsIds);
            
            Log.info(message);
        }
        
        private function onReplaceThingsFromFiles(list:Vector.<PathHelper>):void
        {
            if (!list) {
                throw new NullArgumentError("list");
            }
            
            var length:uint = list.length;
            if (length == 0) return;
            
            //============================================================================
            // Load things
            
            var loader:ThingDataLoader = new ThingDataLoader();
            loader.addEventListener(ProgressEvent.PROGRESS, progressHandler);
            loader.addEventListener(Event.COMPLETE, completeHandler);
            loader.addEventListener(ErrorEvent.ERROR, errorHandler);
            loader.loadFiles(list);
            
            sendCommand(new ShowProgressBarCommand(ProgressBarID.DEFAULT, Resources.getString("loading")));
            
            function progressHandler(event:ProgressEvent):void
            {
                sendCommand(new ProgressCommand(event.id, event.loaded, event.total));
            }
            
            function completeHandler(event:Event):void
            {
                sendCommand(new HideProgressBarCommand(ProgressBarID.DEFAULT));
                onReplaceThings(loader.thingDataList);
            }
            
            function errorHandler(event:ErrorEvent):void
            {
                sendCommand(new HideProgressBarCommand(ProgressBarID.DEFAULT));
                Log.error(event.text);
            }
        }
        
        private function onImportThings(list:Vector.<ThingData>):void
        {
            if (!list) {
                throw new NullArgumentError("list");
            }
            
            var length:uint = list.length;
            if (length == 0) return;
            
            //============================================================================
            // Add sprites
            
            var result:ChangeResult;
            var spritesIds:Vector.<uint> = new Vector.<uint>();
            for (var i:uint = 0; i < length; i++) {
                var thing:ThingType = list[i].thing;
                var sprites:Vector.<SpriteData> = list[i].sprites;
                var len:uint = sprites.length;
                
                for (var k:uint = 0; k < len; k++) {
                    var spriteData:SpriteData = sprites[k];
                    var id:uint = spriteData.id;
                    if (spriteData.isEmpty()) {
                        id = 0;
                    } else if (!m_sprites.hasSpriteId(id) || !m_sprites.compare(id, spriteData.pixels)) {
                        result = m_sprites.addSprite(spriteData.pixels);
                        if (!result.done) {
                            Log.error(result.message);
                            return;
                        }
                        id = m_sprites.spritesCount;
                        spritesIds[spritesIds.length] = id;
                    }
                    thing.spriteIDs[k] = id;
                }
            }
            
            //============================================================================
            // Add things
            
            var thingsToAdd:Vector.<ThingType> = new Vector.<ThingType>(length, true);
            for (i = 0; i < length; i++) {
                thingsToAdd[i] = list[i].thing;
            }
            result = m_things.addThings(thingsToAdd);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            var addedThings:Array = result.list;
            
            //============================================================================
            // Send changes
            
            var message:String;
            
            if (spritesIds.length > 0)
            {
                this.sendSpriteList(Vector.<uint>([m_sprites.spritesCount]));
                
                message = Resources.getString(
                    "logAdded",
                    toLocale("sprite", spritesIds.length > 1),
                    spritesIds);
                
                Log.info(message);
            }
            
            var thingsIds:Vector.<uint> = new Vector.<uint>(length, true);
            for (i = 0; i < length; i++) {
                thingsIds[i] = addedThings[i].id;
            }
            
            var category:String = list[0].thing.category;
            this.setSelectedThingIds(thingsIds, category);
            
            message = Resources.getString(
                "logAdded",
                toLocale(category, thingsIds.length > 1),
                thingsIds);
            
            Log.info(message);
        }
        
        private function onImportThingsFromFiles(list:Vector.<PathHelper>):void
        {
            if (!list) {
                throw new NullArgumentError("list");
            }
            
            var length:uint = list.length;
            if (length == 0) return;
            
            //============================================================================
            // Load things
            
            var loader:ThingDataLoader = new ThingDataLoader();
            loader.addEventListener(ProgressEvent.PROGRESS, progressHandler);
            loader.addEventListener(Event.COMPLETE, completeHandler);
            loader.addEventListener(ErrorEvent.ERROR, errorHandler);
            loader.loadFiles(list);
            
            sendCommand(new ShowProgressBarCommand(ProgressBarID.DEFAULT, Resources.getString("loading")));
            
            function progressHandler(event:ProgressEvent):void
            {
                sendCommand(new ProgressCommand(event.id, event.loaded, event.total));
            }
            
            function completeHandler(event:Event):void
            {
                sendCommand(new HideProgressBarCommand(ProgressBarID.DEFAULT));
                onImportThings(loader.thingDataList);
            }
            
            function errorHandler(event:ErrorEvent):void
            {
                sendCommand(new HideProgressBarCommand(ProgressBarID.DEFAULT));
                Log.error(event.text);
            }
        }
        
        private function onDuplicateThing(list:Vector.<uint>, category:String):void
        {
            if (!list) {
                throw new NullArgumentError("list");
            }
            
            if (!ThingCategory.getCategory(category)) {
                throw new Error(Resources.getString("invalidCategory"));
            }
            
            var length:uint = list.length;
            if (length == 0) return;
            
            //============================================================================
            // Duplicate things
            
            list.sort(Array.NUMERIC);
            
            var thingsCopyList:Vector.<ThingType> = new Vector.<ThingType>();
            
            for (var i:uint = 0; i < length; i++) {
                var thing:ThingType = m_things.getThingType(list[i], category);
                if (!thing) {
                    throw new Error(Resources.getString(
                        "thingNotFound",
                        Resources.getString(category),
                        list[i]));
                }
                thingsCopyList[i] = thing.clone();
            }
            
            var result:ChangeResult = m_things.addThings(thingsCopyList);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            var addedThings:Array = result.list;
            
            //============================================================================
            // Send changes
            
            length = addedThings.length;
            var thingIds:Vector.<uint> = new Vector.<uint>(length, true);
            for (i = 0; i < length; i++) {
                thingIds[i] = addedThings[i].id;
            }
            
            this.setSelectedThingIds(thingIds, category);
            
            thingIds.sort(Array.NUMERIC);
            var message:String = StringUtil.format(Resources.getString(
                "logDuplicated"),
                toLocale(category, thingIds.length > 1),
                list);
            
            Log.info(message);
        }
        
        private function onRemoveThings(list:Vector.<uint>, category:String, removeSprites:Boolean):void
        {
            if (!list) {
                throw new NullArgumentError("list");
            }
            
            if (!ThingCategory.getCategory(category)) {
                throw new ArgumentError(Resources.getString("invalidCategory"));
            }
            
            var length:uint = list.length;
            if (length == 0) return;
            
            //============================================================================
            // Remove things
            
            var result:ChangeResult = m_things.removeThings(list, category);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            var removedThingList:Array = result.list;
            
            //============================================================================
            // Remove sprites
            
            var removedSpriteList:Array;
            
            if (removeSprites) {
                var sprites:Object = {};
                var id:uint;
                
                length = removedThingList.length;
                for (var i:uint = 0; i < length; i++) {
                    var spriteIDs:Vector.<uint> = removedThingList[i].spriteIDs;
                    var len:uint = spriteIDs.length;
                    for (var k:uint = 0; k < len; k++) {
                        id = spriteIDs[k];
                        if (id != 0) {
                            sprites[id] = id;
                        }
                    }
                }
                
                var spriteIds:Vector.<uint> = new Vector.<uint>();
                for each(id in sprites) {
                    spriteIds[spriteIds.length] = id;
                }
                
                result = m_sprites.removeSprites(spriteIds);
                if (!result.done) {
                    Log.error(result.message);
                    return;
                }
                
                removedSpriteList = result.list;
            }
            
            //============================================================================
            // Send changes
            
            var message:String;
            
            length = removedThingList.length;
            var thingIds:Vector.<uint> = new Vector.<uint>(length, true);
            for (i = 0; i < length; i++) {
                thingIds[i] = removedThingList[i].id;
            }
            
            this.setSelectedThingIds(thingIds, category);
            
            thingIds.sort(Array.NUMERIC);
            message = Resources.getString(
                "logRemoved",
                toLocale(category, thingIds.length > 1),
                thingIds);
            
            Log.info(message);
            
            // Sprites changes
            if (removeSprites && spriteIds.length != 0)
            {
                spriteIds.sort(Array.NUMERIC);
                sendSpriteList(Vector.<uint>([ spriteIds[0] ]));
                
                message = Resources.getString(
                    "logRemoved",
                    toLocale("sprite", spriteIds.length > 1),
                    spriteIds);
                
                Log.info(message);
            }
        }
        
        private function onGetThingList(targetId:uint, category:String):void
        {
            if (isNullOrEmpty(category))
                throw new NullOrEmptyArgumentError("category");
            
            sendThingList(Vector.<uint>([ targetId ]), category);
        }
        
        private function onFindThing(category:String, properties:Vector.<ThingProperty>):void
        {
            if (!ThingCategory.getCategory(category))
                throw new ArgumentError(Resources.getString("invalidCategory"));
            
            if (!properties)
                throw new NullArgumentError("properties");
            
            var list:Vector.<ListItem> = new Vector.<ListItem>();
            var things:Vector.<ThingType> = m_things.findThingTypeByProperties(category, properties);
            var length:uint = things.length;
            var rect:Rectangle = new Rectangle();
            
            for (var i:uint = 0; i < length; i++) {
                var thing:ThingType = things[i];
                var bitmap:BitmapData = getThingTypeBitmap(thing.id, thing.category);
                
                rect.width = bitmap.width;
                rect.height = bitmap.height;
                
                var listItem:ListItem = new ListItem();
                listItem.width = bitmap.width;
                listItem.height = bitmap.height;
                listItem.name = thing.marketName;
                listItem.id = thing.id;
                listItem.pixels = bitmap.getVector(rect);
                list[i] = listItem;
            }
            sendCommand(new FindResultCommand(FindResultCommand.THINGS, list));
        }
        
        private function onReplaceSprites(sprites:Vector.<SpriteData>):void
        {
            if (!sprites) {
                throw new NullArgumentError("sprites");
            }
            
            var length:uint = sprites.length;
            if (length == 0) return;
            
            //============================================================================
            // Replace sprites
            
            var result:ChangeResult = m_sprites.replaceSprites(sprites);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            //============================================================================
            // Send changes
            
            var spriteIds:Vector.<uint> = new Vector.<uint>(length, true);
            for (var i:uint = 0; i < length; i++) {
                spriteIds[i] = sprites[i].id;
            }
            
            this.setSelectedSpriteIds(spriteIds);
                
            var message:String = Resources.getString(
                "logReplaced",
                toLocale("sprite", sprites.length > 1),
                spriteIds);
            
            Log.info(message);
        }
        
        private function onReplaceSpritesFromFiles(list:Vector.<PathHelper>):void
        {
            if (!list) {
                throw new NullArgumentError("list");
            }
            
            if (list.length == 0) return;
            
            //============================================================================
            // Load sprites
            
            var loader:SpriteDataLoader = new SpriteDataLoader();
            loader.addEventListener(Event.COMPLETE, completeHandler);
            loader.addEventListener(ProgressEvent.PROGRESS, progressHandler);
            loader.loadFiles(list);
            
            sendCommand(new ShowProgressBarCommand(ProgressBarID.DEFAULT, Resources.getString("loading")));
            
            function progressHandler(event:ProgressEvent):void
            {
                sendCommand(new ProgressCommand(event.id, event.loaded, event.total));
            }
            
            function completeHandler(event:Event):void
            {
                sendCommand(new HideProgressBarCommand(ProgressBarID.DEFAULT));
                onReplaceSprites(loader.spriteDataList);
            }
        }
        
        private function onAddSprites(sprites:Vector.<ByteArray>):void
        {
            if (!sprites) {
                throw new NullArgumentError("sprites");
            }
            
            if (sprites.length == 0) return;
            
            //============================================================================
            // Add sprites
            
            var result:ChangeResult = m_sprites.addSprites(sprites);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            var spriteAddedList:Array = result.list;
            
            //============================================================================
            // Send changes to application
            
            var ids:Array = [];
            var length:uint = spriteAddedList.length;
            for (var i:uint = 0; i < length; i++) {
                ids[i] = spriteAddedList[i].id;
            }
            
            sendSpriteList(Vector.<uint>([ ids[0] ]));
            
            ids.sort(Array.NUMERIC);
            var message:String = Resources.getString(
                "logAdded",
                toLocale("sprite", ids.length > 1),
                ids);
            
            Log.info(message);
        }
        
        private function onImportSpritesFromFiles(list:Vector.<PathHelper>):void
        {
            if (!list) {
                throw new NullArgumentError("list");
            }
            
            if (list.length == 0) return;
            
            //============================================================================
            // Load sprites
            
            var loader:SpriteDataLoader = new SpriteDataLoader();
            loader.addEventListener(ProgressEvent.PROGRESS, progressHandler);
            loader.addEventListener(Event.COMPLETE, completeHandler);
            loader.addEventListener(ErrorEvent.ERROR, errorHandler);
            loader.loadFiles(list);
            
            sendCommand(new ShowProgressBarCommand(ProgressBarID.DEFAULT, Resources.getString("loading")));
            
            function progressHandler(event:ProgressEvent):void
            {
                sendCommand(new ProgressCommand(event.id, event.loaded, event.total));
            }
            
            function completeHandler(event:Event):void
            {
                sendCommand(new HideProgressBarCommand(ProgressBarID.DEFAULT));
                
                var spriteDataList:Vector.<SpriteData> = loader.spriteDataList;
                var length:uint = spriteDataList.length;
                var sprites:Vector.<ByteArray> = new Vector.<ByteArray>(length, true);
                
                VectorUtils.sortOn(spriteDataList, "id", Array.NUMERIC | Array.DESCENDING);
                
                for (var i:uint = 0; i < length; i++) {
                    sprites[i] = spriteDataList[i].pixels;
                }
                
                onAddSprites(sprites);
            }
            
            function errorHandler(event:ErrorEvent):void
            {
                sendCommand(new HideProgressBarCommand(ProgressBarID.DEFAULT));
                Log.error(event.text);
            }
        }
        
        private function onExportSprites(files:Vector.<File>,
                                         ids:Vector.<uint>,
                                         backgroundColor:uint,
                                         jpegQuality:uint):void
        {
            if (isNullOrEmpty(files))
                throw new NullOrEmptyArgumentError("files");
            
            if (isNullOrEmpty(ids))
                throw new NullOrEmptyArgumentError("ids");
            
            if (files.length != ids.length)
                throw new ArgumentError("Length of files list differs from length of ids list.");
            
            //============================================================================
            // Save sprites
            
            sendCommand(new ShowProgressBarCommand(ProgressBarID.DEFAULT, Resources.getString("exportingSprites")));
            
            var helper:SaveHelper = new SaveHelper();
            var length:uint = files.length;
            for (var i:uint = 0; i < length; i++) {
                var file:File = files[i];
                var id:uint = ids[i];
                var name:String = FileUtil.getName(file);
                var format:String = file.extension;
                if (ImageFormat.hasImageFormat(format) && id != 0) {
                    var bitmap:BitmapData = m_sprites.getBitmap(id);
                    if (bitmap) {
                        var bytes:ByteArray = ImageCodec.encode(bitmap, format, jpegQuality);
                        helper.addFile(bytes, name, format, file);
                    }
                }
            }
            helper.addEventListener(flash.events.ProgressEvent.PROGRESS, progressHandler);
            helper.addEventListener(Event.COMPLETE, completeHandler);
            helper.save();
            
            function progressHandler(event:flash.events.ProgressEvent):void
            {
                sendCommand(new ProgressCommand(ProgressBarID.DEFAULT, event.bytesLoaded, event.bytesTotal));
            }
            
            function completeHandler(event:Event):void
            {
                sendCommand(new HideProgressBarCommand(ProgressBarID.DEFAULT));
            }
        }
        
        private function onNewSprite():void
        {
            if (m_sprites.isFull) {
                Log.error(Resources.getString("spritesLimitReached"));
                return;
            }
            
            //============================================================================
            // Add sprite
            
            var rect:Rectangle = new Rectangle(0, 0, otlib.sprites.Sprite.DEFAULT_SIZE, otlib.sprites.Sprite.DEFAULT_SIZE);
            var pixels:ByteArray = new BitmapData(rect.width, rect.height, true, 0).getPixels(rect);
            var result:ChangeResult = m_sprites.addSprite(pixels);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            //============================================================================
            // Send changes
            
            sendSpriteList(Vector.<uint>([ m_sprites.spritesCount ]));
            
            var message:String = Resources.getString(
                "logAdded",
                Resources.getString("sprite"),
                m_sprites.spritesCount);
            Log.info(message);
        }
        
        private function onRemoveSprites(list:Vector.<uint>):void
        {
            if (!list) {
                throw new NullArgumentError("list");
            }
            
            //============================================================================
            // Removes sprites
            
            var result:ChangeResult = m_sprites.removeSprites(list);
            if (!result.done) {
                Log.error(result.message);
                return;
            }
            
            //============================================================================
            // Send changes
            
            // Select sprites
            this.setSelectedSpriteIds(list);
            
            // Send message to log
            var message:String = Resources.getString(
                "logRemoved",
                toLocale("sprite", list.length > 1),
                list);
                
            Log.info(message);
        }
        
        private function onGetSpriteList(targetId:uint):void
        {
            sendSpriteList(Vector.<uint>([ targetId ]));
        }
        
        private function onNeedToReload(extended:Boolean,
                                        transparency:Boolean,
                                        improvedAnimations:Boolean):void
        {
            onLoadFiles(m_datFile.nativePath,
                        m_sprFile.nativePath,
                        m_version.datSignature,
                        m_version.sprSignature,
                        extended,
                        transparency,
                        improvedAnimations);
        }
        
        private function onFindSprites(unusedSprites:Boolean, emptySprites:Boolean):void
        {
            var finder:SpritesFinder = new SpritesFinder(m_things, m_sprites);
            finder.addEventListener(ProgressEvent.PROGRESS, progressHandler);
            finder.addEventListener(Event.COMPLETE, completeHandler);
            finder.start(unusedSprites, emptySprites);
            
            function progressHandler(event:ProgressEvent):void
            {
                sendCommand(new ProgressCommand(ProgressBarID.FIND,
                                                event.loaded,
                                                event.total));
            }
            
            function completeHandler(event:Event):void
            {
                var command:Command = new FindResultCommand(FindResultCommand.SPRITES, finder.foundList);
                sendCommand(command);
            }
        }
        
        private function onOptimizeSprites(unusedSprites:Boolean, emptySprites:Boolean):void
        {
            var optimizer:SpritesOptimizer = new SpritesOptimizer(m_things, m_sprites);
            optimizer.addEventListener(ProgressEvent.PROGRESS, progressHandler);
            optimizer.addEventListener(Event.COMPLETE, completeHandler);
            optimizer.start(unusedSprites, emptySprites);
            
            function progressHandler(event:ProgressEvent):void
            {
                sendCommand(new ProgressCommand(ProgressBarID.OPTIMIZE,
                                                event.loaded,
                                                event.total,
                                                event.label));
            }
            
            function completeHandler(event:Event):void
            {
                if (optimizer.removedCount > 0)
                {
                    sendClientInfo();
                    sendSpriteList(Vector.<uint>([0]));
                    sendThingList(Vector.<uint>([100]), ThingCategory.ITEM);
                }
                
                var command:Command = new OptimizeSpritesResultCommand(optimizer.removedCount,
                                                                       optimizer.oldCount,
                                                                       optimizer.newCount);
                
                sendCommand(command);
            }
        }
        
        private function clientLoadComplete():void
        {
            sendCommand(new HideProgressBarCommand(ProgressBarID.DAT_SPR));
            sendClientInfo();
            sendThingList(Vector.<uint>([ThingTypeStorage.MIN_ITEM_ID]), ThingCategory.ITEM);
            sendThingData(Vector.<uint>([ThingTypeStorage.MIN_ITEM_ID]), ThingCategory.ITEM);
            sendSpriteList(Vector.<uint>([0]));
            Log.info(Resources.getString("loadComplete"));
        }
        
        private function clientCompileComplete():void
        {
            sendCommand(new HideProgressBarCommand(ProgressBarID.DAT_SPR));
            sendClientInfo();
            Log.info(Resources.getString("compileComplete"));
        }
        
        public function sendClientInfo():void
        {
            var info:ClientInfo = new ClientInfo();
            info.loaded = clientLoaded;
            
            if (info.loaded)
            {
                info.clientVersion = m_version.value;
                info.clientVersionStr = m_version.description;
                info.datSignature = m_things.signature;
                info.minItemId = ThingTypeStorage.MIN_ITEM_ID;
                info.maxItemId = m_things.itemsCount;
                info.minOutfitId = ThingTypeStorage.MIN_OUTFIT_ID;
                info.maxOutfitId = m_things.outfitsCount;
                info.minEffectId = ThingTypeStorage.MIN_EFFECT_ID;
                info.maxEffectId = m_things.effectsCount;
                info.minMissileId = ThingTypeStorage.MIN_MISSILE_ID;
                info.maxMissileId = m_things.missilesCount;
                info.sprSignature = m_sprites.signature;
                info.minSpriteId = 0;
                info.maxSpriteId = m_sprites.spritesCount;
                info.extended = m_extended;
                info.transparency = m_transparency;
                info.improvedAnimations = m_improvedAnimations;
                info.changed = clientChanged;
                info.isTemporary = clientIsTemporary;
            }
            
            sendCommand(new SetClientInfoCommand(info));
        }
        
        private function sendThingList(selectedIds:Vector.<uint>, category:String):void
        {
            if (!selectedIds)
                throw new NullArgumentError("selectedIds");
            
            if (isNullOrEmpty(category))
                throw new NullOrEmptyArgumentError("category");
            
            var first:uint = m_things.getMinId(category);
            var last:uint = m_things.getMaxId(category);
            var length:uint = selectedIds.length;
            
            if (length > 1)
                selectedIds = selectedIds.sort(Array.NUMERIC | Array.DESCENDING);
            
            if (selectedIds[length - 1] > last)
                selectedIds = Vector.<uint>([last]);
            
            var target:uint = length == 0 ? 0 : selectedIds[0];
            var min:uint = Math.max(first, ObUtils.hundredFloor(target));
            var diff:uint = (category != ThingCategory.ITEM && min == first) ? 1 : 0;
            var max:uint = Math.min((min - diff) + (m_thingListAmount - 1), last);
            var list:Vector.<ListItem> = new Vector.<ListItem>();
            var rect:Rectangle = new Rectangle();
            
            for (var id:uint = min; id <= max; id++) {
                var thing:ThingType = m_things.getThingType(id, category);
                var image:BitmapData = getThingTypeBitmap(id, category);
                
                rect.width = image.width;
                rect.height = image.height;
                
                var item:ListItem = new ListItem();
                item.width = image.width;
                item.height = image.height;
                item.name = thing.marketName;
                item.id = id;
                item.pixels = image.getVector(rect);
                list[list.length] = item;
            }
            
            m_thingListMinMax.setTo(min, max);
            m_thingCategory = category;
            sendCommand(new SetThingListCommand(category, list, selectedIds));
        }
        
        private function sendThingData(id:uint, category:String):void
        {
            var thingData:ThingData = getThingData(id, category, OBDVersions.OBD_VERSION_2, m_version.value);
            if (thingData)
                sendCommand(new SetThingDataCommand(thingData));
        }
        
        private function sendSpriteList(selectedIds:Vector.<uint>):void
        {
            if (!selectedIds)
                throw new NullArgumentError("selectedIds");
            
            var first:uint = 0;
            var last:uint = m_sprites.spritesCount;
            var length:uint = selectedIds.length;
            
            if (length > 1)
                selectedIds = selectedIds.sort(Array.NUMERIC | Array.DESCENDING);
            
            if (selectedIds[length - 1] > last)
                selectedIds = Vector.<uint>([last]);
            
            var target:uint = length == 0 ? 0 : selectedIds[0];
            var min:uint = Math.max(first, ObUtils.hundredFloor(target));
            var max:uint = Math.min(min + (m_spriteListAmount - 1), last);
            var list:Vector.<ListItem> = new Vector.<ListItem>();
            var size:uint = otlib.sprites.Sprite.DEFAULT_SIZE;
            
            for (var id:uint = min; id <= max; id++) {
                var item:ListItem = new ListItem();
                item.width = size;
                item.height = size;
                item.id = id;
                item.pixels = m_sprites.getPixelsVector(id);
                list[list.length] = item;
            }
            
            m_spriteListMinMax.setTo(min, max);
            sendCommand(new SetSpriteListCommand(list, selectedIds));
        }
        
        private function getThingTypeBitmap(id:uint, category:String):BitmapData
        {
            var thing:ThingType = m_things.getThingType(id, category);
            var size:uint = otlib.sprites.Sprite.DEFAULT_SIZE;
            var width:uint = thing.width;
            var height:uint = thing.height;
            var layers:uint = thing.layers;
            var bitmap:BitmapData = new BitmapData(width * size, height * size, true, 0xFF636363);
            var x:uint;
            
            if (thing.category == ThingCategory.OUTFIT) {
                layers = 1;
                x = thing.frames > 1 ? 2 : 0;
            }
            
            for (var l:uint = 0; l < layers; l++) {
                for (var w:uint = 0; w < width; w++) {
                    for (var h:uint = 0; h < height; h++) {
                        var index:uint = thing.getSpriteIndex(w, h, l, x, 0, 0, 0);
                        var px:int = (width - w - 1) * size;
                        var py:int = (height - h - 1) * size;
                        m_sprites.copyPixels(thing.spriteIDs[index], bitmap, px, py);
                    }
                }
            }
            return bitmap;
        }
        
        private function getThingData(id:uint, category:String, obdVersion:uint, clientVersion:uint):ThingData
        {
            if (!ThingCategory.getCategory(category)) {
                throw new Error(Resources.getString("invalidCategory"));
            }
            
            var thing:ThingType = m_things.getThingType(id,  category);
            if (!thing) {
                throw new Error(Resources.getString(
                    "thingNotFound",
                    Resources.getString(category),
                    id));
            }
            
            var sprites:Vector.<SpriteData> = new Vector.<SpriteData>();
            var spriteIDs:Vector.<uint> = thing.spriteIDs;
            var length:uint = spriteIDs.length;
            
            for (var i:uint = 0; i < length; i++) {
                var spriteId:uint = spriteIDs[i];
                var pixels:ByteArray = m_sprites.getPixels(spriteId);
                if (!pixels) {
                    Log.error(Resources.getString("spriteNotFound", spriteId));
                    pixels = m_sprites.alertSprite.pixels;
                }
                
                var spriteData:SpriteData = new SpriteData();
                spriteData.id = spriteId;
                spriteData.pixels = pixels;
                sprites.push(spriteData);
            }
            return ThingData.create(obdVersion, clientVersion, thing, sprites);
        }
        
        private function toLocale(bundle:String, plural:Boolean = false):String
        {
            return Resources.getString(bundle + (plural ? "s" : "")).toLowerCase();
        }
        
        //--------------------------------------
        // Event Handlers
        //--------------------------------------
        
        protected function storageLoadHandler(event:StorageEvent):void
        {
            if (event.target == m_things || event.target == m_sprites)
            {
                if (m_things.loaded && m_sprites.loaded)
                    this.clientLoadComplete();
            }
        }
        
        protected function storageChangeHandler(event:StorageEvent):void
        {
            sendClientInfo();
        }
        
        protected function thingsProgressHandler(event:ProgressEvent):void
        {
            sendCommand(new ProgressCommand(event.id, event.loaded, event.total));
        }
        
        protected function thingsErrorHandler(event:ErrorEvent):void
        {
            // Try load as extended.
            if (!m_things.loaded && !m_extended)
            {
                m_errorMessage = event.text;
                onLoadFiles(m_datFile.nativePath,
                            m_sprFile.nativePath,
                            m_version.datSignature,
                            m_version.sprSignature,
                            true,
                            m_transparency,
                            m_improvedAnimations);
            }
            else
            {
                if (m_errorMessage)
                {
                    Log.error(m_errorMessage);
                    m_errorMessage = null;
                }
                else
                    Log.error(event.text);
            }
        }
        
        protected function spritesProgressHandler(event:ProgressEvent):void
        {
            sendCommand(new ProgressCommand(event.id, event.loaded, event.total));
        }
        
        protected function spritesErrorHandler(event:ErrorEvent):void
        {
            Log.error(event.text, "", event.errorID);
        }
    }
}
