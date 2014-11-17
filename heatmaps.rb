<<END
Copyright (c) 2011 Philipp Seifried

Permission is hereby granted, free of charge, to any person obtaining 
a copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the 
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included 
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
END

# Demonstrates how to draw a heatmap by creating a 24-bit intermediate gradient map.
# Click anywhere in the top left part of the application to add clicks.

require 'ruby-processing'

Processing::App::SKETCH_PATH = __FILE__

class Heatmaps < Processing::App
  attr_accessor :backgroundImage, :heatmapBrush, :heatmapColors, :clickmapBrush, :gradientMap, :heatmap, :clickmap, :maxValue, :dir
  
  def initialize
    self.maxValue = 0

    self.dir = Dir.pwd+'/'

    super(x: 0, y: 0)
  end
  
  def setup
    size(1000, 740);
    background(0,0,0);
    
    # load image data:
    self.backgroundImage = loadImage(dir+"images/townsquare.jpg")
    self.heatmapColors = loadImage(dir+"images/heatmapColors.png")
    self.heatmapBrush = loadImage(dir+"images/heatmapBrush.png")
    self.clickmapBrush = loadImage(dir+"images/clickmapBrush.png")
    
     # draw the background image in the upper left corner.
    image(backgroundImage, 0,0);
  
    # create empty canvases:
    self.clickmap = createImage(backgroundImage.width, backgroundImage.height, ARGB);
    self.gradientMap = createImage(backgroundImage.width, backgroundImage.height, ARGB);
    self.heatmap = createImage(backgroundImage.width, backgroundImage.height, ARGB);
    # load pixel arrays for all relevant images
    gradientMap.loadPixels();
    gradientMap.pixels.each{|p| p = 0 }
    heatmap.loadPixels();
    heatmapBrush.loadPixels();
    heatmapColors.loadPixels();
  end
  
  def draw() # empty but needed for Processing to call the mouseReleased function
  end
  
  # The mouse click handler updates the clickmap, gradient map and heatmap and redraws all of them
  def mouseReleased()
    if (mouseX >= 0 && mouseX < backgroundImage.width && mouseY >= 0 && mouseY < backgroundImage.height) # we're only concerned about clicks in the upper right image!
      # blit the clickmapBrush onto the (offscreen) clickmap:
      clickmap.blend(clickmapBrush, 0,0,clickmapBrush.width,clickmapBrush.height,mouseX-clickmapBrush.width/2,mouseY-clickmapBrush.height/2,clickmapBrush.width,clickmapBrush.height,BLEND);
      # blit the clickmapBrush onto the background image in the upper left corner:
      image(clickmapBrush, mouseX-clickmapBrush.width/2, mouseY-clickmapBrush.height/2);
      
      # render the heatmapBrush into the gradientMap:
      drawToGradient(mouseX, mouseY);
      # update the heatmap from the updated gradientMap:
      updateHeatmap();
      
      # draw the gradientMap in the lower left corner:
      image(gradientMap, 0, backgroundImage.height);
      
      # draw the background image in the upper right corner and transparently blend the heatmap on top of it:
      image(backgroundImage, backgroundImage.width,0);
      tint(255,255,255,192);
      image(heatmap, backgroundImage.width, 0);
      noTint();
      
      # draw the raw heatmap into the bottom right corner and draw the clickmap on top of it:
      image(heatmap, backgroundImage.width, backgroundImage.height);
      image(clickmap, backgroundImage.width, backgroundImage.height);
    end
  end
  
  
  # Rendering code that blits the heatmapBrush onto the gradientMap, centered at the specified pixel and drawn with additive blending
  
  def drawToGradient(x, y)
    # find the top left corner coordinates on the target image
    startX = x-heatmapBrush.width/2;
    startY = y-heatmapBrush.height/2;
  
    (0...heatmapBrush.height).each do |py|
      (0...heatmapBrush.width).each do |px|
        # for every pixel in the heatmapBrush:
        
        # find the corresponding coordinates on the gradient map:
        hmX = startX+px;
        hmY = startY+py;
        
        #The next if-clause checks if we're out of bounds and skips to the next pixel if so.
        #Note that you'd typically optimize by performing clipping outside of the for loops!
        next if (hmX < 0 || hmY < 0 || hmX >= gradientMap.width || hmY >= gradientMap.height)
        
        # get the color of the heatmapBrush image at the current pixel.
        col = heatmapBrush.pixels[py*heatmapBrush.width+px]; # The py*heatmapBrush.width+px part would normally also be optimized by just incrementing the index.
        col = col & 0xff; # This eliminates any part of the heatmapBrush outside of the blue color channel (0xff is the same as 0x0000ff)
        
        # find the corresponding pixel image on the gradient map:
        gmIndex = hmY*gradientMap.width+hmX;
        
        if (gradientMap.pixels[gmIndex] < 0xffffff-col) # sanity check to make sure the gradient map isn't "saturated" at this pixel. This would take some 65535 clicks on the same pixel to happen. :)
          gradientMap.pixels[gmIndex] += col; # additive blending in our 24-bit world: just add one value to the other.
          if (gradientMap.pixels[gmIndex] > maxValue) # We're keeping track of the maximum pixel value on the gradient map, so that the heatmap image can display relative click densities (scroll down to updateHeatmap() for more)
            self.maxValue = gradientMap.pixels[gmIndex];
          end
        end
      end
    end
    gradientMap.updatePixels();
  end
  
  # Updates the heatmap from the gradient map.
  def updateHeatmap()
    # for all pixels in the gradient:
    (0...gradientMap.pixels.length).each do |i|
      # get the pixel's value. Note that we're not extracting any channels, we're just treating the pixel value as one big integer.
      # cast to float is done to avoid integer division when dividing by the maximum value.
      gmValue = gradientMap.pixels[i].to_f;
      
      # color map the value. gmValue/maxValue normalizes the pixel from 0...1, the rest is just mapping to an index in the heatmapColors data.
      colIndex = ((gmValue/maxValue)*(heatmapColors.pixels.length-1)).to_i;
      col = heatmapColors.pixels[colIndex];
  
      # update the heatmap at the corresponding position
      heatmap.pixels[i] = col;
    end
    # load the updated pixel data into the PImage.
    heatmap.updatePixels();
  end
end 

Heatmaps.new()
