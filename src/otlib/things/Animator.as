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

package otlib.things
{
    import flash.utils.getTimer;
    
    import otlib.otml.OTMLNode;
    
    public class Animator
    {
        //--------------------------------------------------------------------------
        // PROPERTIES
        //--------------------------------------------------------------------------
        
        public var animationMode:int;
        public var loopCount:int;
        public var frameDurations:Vector.<FrameDuration>;
        public var frames:uint;
        public var startFrame:int;
        public var skipFirstFrame:Boolean;
        
        private var m_lastTime:Number = 0;
        private var m_currentFrameDuration:uint;
        private var m_currentFrame:uint;
        private var m_currentLoop:uint;
        private var m_currentDirection:uint;
        private var m_isComplete:Boolean;
        
        //--------------------------------------
        // Getters / Setters
        //--------------------------------------
        
        public function get frame():int { return m_currentFrame; }
        public function set frame(value:int):void
        {
            if (m_currentFrame == value) return;
            
            if (this.animationMode == AnimationMode.ASYNCHRONOUS) {
                
                if (value == FRAME_ASYNCHRONOUS)
                    m_currentFrame = 0;
                else if (value == FRAME_RANDOM)
                    m_currentFrame = Math.floor(Math.random() * this.frames);
                else if (value >= 0 && value < this.frames)
                    m_currentFrame = value;
                else
                    m_currentFrame = this.getStartFrame();
                
                m_isComplete = false;
                m_lastTime = getTimer();
                m_currentFrameDuration = this.frameDurations[m_currentFrame].duration;
            
            } else
                this.calculateSynchronous();
        }
        
        public function get isComplete():Boolean { return m_isComplete; }
        
        //--------------------------------------------------------------------------
        // CONSTRUCTOR
        //--------------------------------------------------------------------------
        
        public function Animator()
        {
        }
        
        //--------------------------------------------------------------------------
        // METHODS
        //--------------------------------------------------------------------------
        
        //--------------------------------------
        // Public
        //--------------------------------------
        
        public function update(time:Number):void
        {
            if (time != m_lastTime && !m_isComplete) {
                var elapsed:Number = time - m_lastTime;
                if (elapsed >= m_currentFrameDuration) {
                    var frame:uint = loopCount < 0 ? getPingPongFrame() : getLoopFrame();
                    if (m_currentFrame != frame) {
                        var duration:int = this.frameDurations[frame].duration - (elapsed - m_currentFrameDuration);
                        if (duration < 0 && this.animationMode == AnimationMode.SYNCHRONOUS)
                            this.calculateSynchronous();
                        else {
                            m_currentFrame = skipFirstFrame && frame == 0 ? 1 % frames : frame;
                            m_currentFrameDuration = Math.max(0, duration);
                        }
                    } else
                        m_isComplete = true;
                } else
                    m_currentFrameDuration = m_currentFrameDuration - elapsed;
                
                m_lastTime = time;
            }
        }
        
        public function clone():Animator
        {
            var clone:Animator = new Animator();
            clone.loopCount = loopCount;
            clone.frames = frames;
            clone.startFrame = startFrame;
            clone.animationMode = animationMode;
            clone.frameDurations = frameDurations;
            clone.skipFirstFrame = skipFirstFrame;
            clone.frame = FRAME_AUTOMATIC;
            return clone;
        }
        
        public function getStartFrame():uint
        {
            if (this.startFrame > -1)
                return this.startFrame;
            
            return Math.floor(Math.random() * this.frames);
        }
        
        public function reset():void
        {
            frame = FRAME_AUTOMATIC;
            m_currentLoop = 0;
            m_currentDirection = FORWARD;
            m_isComplete = false;
        }
        
        public function serialize():OTMLNode
        {
            var node:OTMLNode = new OTMLNode();
            node.tag = "Animator";
            node.writeAt("animationMode", animationMode);
            node.writeAt("loopCount", loopCount);
            node.writeAt("startFrame", startFrame);
            node.writeAt("frames", frames);
            
            var length:uint = frameDurations.length;
            for (var i:uint = 0; i < length; i++)
                node.addChild(frameDurations[i].serialize());
            
            return node;
        }
        
        public function unserialize(node:OTMLNode):Boolean
        {
            if (node.tag != "Animator") return false;
            
            this.animationMode = node.intAt("animationMode");
            this.loopCount = node.intAt("loopCount");
            this.startFrame = node.intAt("startFrame");
            this.frames = node.intAt("frames");
            
            var nodes:Vector.<OTMLNode> = node.getChildrenAt("FrameDuration");
            if (nodes.length == 0 || nodes.length != this.frames) return false;
            
            var frameDurations:Vector.<FrameDuration> = new Vector.<FrameDuration>(nodes.length, true);
            for (var i:uint = 0; i < nodes.length; i++) {
                var duration:FrameDuration = new FrameDuration();
                if (!duration.unserialize(nodes[i])) return false;
                frameDurations[i] = duration;
            }
            
            this.frameDurations = frameDurations;
            return true;
        }
        
        //--------------------------------------
        // Private
        //--------------------------------------
        
        private function calculateSynchronous():void
        {
            var totalDuration:Number = 0;
            for (var i:uint = 0; i < frames; i++)
                totalDuration += frameDurations[i].duration;
            
            var time:Number = getTimer();
            var elapsed:Number = time % totalDuration;
            var totalTime:Number = 0;
            
            for (i = 0; i < frames; i++) {
                var duration:Number = this.frameDurations[i].duration;
                if (elapsed >= totalTime && elapsed < totalTime + duration) {
                    m_currentFrame = i;
                    var timeDiff:Number = elapsed - totalTime;
                    m_currentFrameDuration = duration - timeDiff;
                    break;
                }
                totalTime += duration;
            }
            m_lastTime = time;
        }
        
        private function getLoopFrame():uint
        {
            var nextFrame:uint = (m_currentFrame + 1);
            if (nextFrame < frames)
                return nextFrame;
            
            if (loopCount == 0)
                return 0;
            
            if (m_currentLoop < (loopCount - 1)) {
                m_currentLoop++;
                return 0;
            }
            return m_currentFrame;
        }
        
        private function getPingPongFrame():uint
        {
            var count:int = m_currentDirection == FORWARD ? 1 : -1;
            var nextFrame:int = m_currentFrame + count;
            if (m_currentFrame + count < 0 || nextFrame >= frames) {
                m_currentDirection = m_currentDirection == FORWARD ? BACKWARD : FORWARD;
                count *= -1;
            }
            return m_currentFrame + count;
        }
        
        //--------------------------------------------------------------------------
        // STATIC
        //--------------------------------------------------------------------------
        
        public static const FRAME_AUTOMATIC:int = -1;
        public static const FRAME_RANDOM:int = 0xFE;
        public static const FRAME_ASYNCHRONOUS:int = 0xFF;
        public static const FORWARD:uint = 0;
        public static const BACKWARD:uint = 1;
        
        public static function create(frames:uint,
                                      startFrame:int,
                                      loopCount:int,
                                      animationMode:int,
                                      frameDurations:Vector.<FrameDuration>):Animator
        {
            if (animationMode != AnimationMode.ASYNCHRONOUS && animationMode != AnimationMode.SYNCHRONOUS)
                throw new ArgumentError("Unexpected animation mode " + animationMode);
            
            if (frameDurations.length != frames)
                throw new ArgumentError("Frame duration differs from frame count");
            
            if (startFrame < -1 || startFrame >= frames)
                throw new ArgumentError("Invalid start frame " + startFrame);
            
            var animator:Animator = new Animator();
            animator.loopCount = loopCount;
            animator.frames = frames;
            animator.startFrame = startFrame;
            animator.animationMode = animationMode;
            animator.frameDurations = frameDurations;
            animator.frame = FRAME_AUTOMATIC;
            return animator;
        }
    }
}
