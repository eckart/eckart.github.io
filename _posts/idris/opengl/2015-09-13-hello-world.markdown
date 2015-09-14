---
layout: post
title:  "Drawing a Triangle with Idris and OpenGL"
date:   2015-09-13
categories: Programming Graphics Idris
---

[1]: http://docs.gl/     "OpenGL Docs"
[2]: http://learnopengl.com "OpenGL Tutorial"
[3]: http://antongerdelan.net/opengl "Anton's OpenGL Tutorial"
[4]: https://www.youtube.com/watch?v=VS8wlS9hF8E&list=PLRIWtICgwaX0u7Rf9zkZhLoLuZVfUksDP "OpenGl Video Tutorials using Java LWGL"
[5]: http://antongerdelan.net/opengl/shaders.html "About Shaders"
[6]: http://antongerdelan.net/opengl/raycasting.html "OpenGL coordinate systems"
[7]: http://www.glfw.org/ "GLFW"
[8]: http://www.idris-lang.org/ "Idris"


Some time ago I decided to simultaneously learn [Idris][8] and 3D graphics programming.
Idris had interested me for some time, and drawing things seemed such a nice application...

I took some time, but now there is a binding for OpenGL in Idris, which you can find it here: [https://github.com/eckart/gl-idris/](https://github.com/eckart/gl-idris/)

This project is basically a direct binding of the core API. And since I am a beginner in both OpenGL and Idris the code is not very refined at this point. 
However we can still do some fun things with it - like drawing a triangle. Ok, so that's no so much fun in itself, but the triangle is the OpenGL version
of the customary "hello world" program.

It is a rather intricate and verbose "hello world" since even for a single triangle we have to 

- install OpenGL
- install some required libraries 
- install a a few depencies the Idris code
- open a window 
- define the triangle geometry and tell OpenGL about it 
- create shader programs that will do the actual rendering
- run the drawing code in an event loop

Until we finally get this:

![Simple Display](/assets/images/hello_world_triangle.png)

This post is actually a literate idris file, which you can download and directly execute to produce the above triangle (provided all the dependencies are installed). 
It is not intended to be an OpenGL tutorial since there are a vast number of OpenGL tutorials available. 
(I like the tutorials from [Learn OpenGL][2] (a series of written tutorials with code in C++) and the video tutorials by [Thinmatrix][4] (which is Java, but he does a good job explaining the basic concepts).
For some more detailed information about OpenGL concepts see [Anton's OpenGL 4 Tutorials][3] .

The source code for this file is [available on github](https://github.com/eckart/eckart.github.io/tree/master/_lidr/opengl/2015-09-13-hello-world.lidr)
in case you want to try it out. 

Of Idris' capabilities we will see very little. The OpenGL binding is intended to be a direct and low-level binding of OpenGL,
and that means : IO Monad and more IO Monad.

However the binding comes with some additional goodies, which we might see in future posts, but for now we will keep to the basic stuff.


### Imports

As mentioned, this post is a literate idris file and we want to produce an executuable that will show us the triangle, so we 
need to provide a `Main` module with a `main` function:

```idris

module Main
  
```

Of course we need to import the OpenGL binding which lives in the module `Graphics.Rendering.Gl`.

```idris 

import Graphics.Rendering.Gl
import Graphics.Rendering.Config   -- bring in some C flags 
import Data.Floats                 -- OpenGL loves floats

```

To be able to see the "hello world" triangle in a window, we need a some functionality to open a display.
This functionality is *not* provided by the OpenGL binding, since OpenGL itself is also completely agnostic to these things.
So we need to use an idris package that *does* not about windows (and how to handle user input). 
Fortunately there is such a package and in fact even more than one.

For simplicity and to run in parallel to the many OpenGL tutorials we will use the [GLFW][7] library and the Idris bindings for GLFW which are available here: [https://github.com/eckart/glfw-idris](https://github.com/eckart/glfw-idris). 

We won't go into detail about how to open the display here. If you are interested you can read [this post](/programming/graphics/idris/2015/08/24/simple-display.html) about it.

```idris 

import Graphics.Util.Glfw
%flag C "-Wno-pointer-sign"  -- suppress an annoying warning

```

For Idris to be able to compile the executable, we need to pass a C flag to the compiler: 

```idris 

%include C "GL/glew.h"

```

This line is absolutely necessary and needs to be in the Main module even if it is only used by the bindings from `Graphics.Rendering.Gl`.
If we do not include the GLEW library, which provides something like a header with all the OpenGL functions in it, Idris - or rather the C compiler - will not be able to
resolve any of the OpenGL functions. 
Actually I have not really understood all the details about, but once the line is present the compile should work.


### Vertices

We are now ready to create the triangle. 
A triangle can be represented by 3 points. Since we are dealing with 3D we will
provide the points as 3-dimensional vectors (in the mathematical sense), like `(1.0, 2.0, -0.5)`. 
The components of the vector will represent the values on the `x`, `y` and `z` axis of a cartesian coordinate system.
(Read more about the coordinate systems in OpenGL [here][6]

In OpenGL speak, each point in space is usually called a `vertex`. For a triangle we need three vertices:

```idris 

vertices : List Double
vertices = [
  -0.8, -0.8,  0.0,   -- left
   0.0,  0.8,  0.0,   -- top
   0.8, -0.8,  0.0    -- right
  ]

```

For simplicity we store all three vertices in a flat list instead of, say a `Vect 3 (Vect 3 Double)`.

The z component usually denotes the _depth_ of the point - how far away the vertex is. 
Additionally we choose the values of x and y components from the range of `[-1,1]`, because otherwise
OpenGL will not show it. 

In addition to the vertices for the position of the corners of the triangle we will provide colors for each
vertex.

The colors will be in RGBA order, that is: a red, a green and a blue component followed by an alpha value
for transparency. The color component values will range from 0.0 to 1.0.

```idris 

colors : List Double
colors = [
   1.0, 0.0, 0.0, 1.0, -- red
   0.0, 1.0, 0.0, 1.0, -- green
   0.0, 0.0, 1.0, 1.0  -- blue
  ]

```

We now need a way to "upload" our data to the GPU. OpenGL will store the vertex data (positions and colors) in something called a *vertex array object (VAO)*. 
The VAO is a container or grouping of several *vertex array buffer object (VBOs)*, which is where data really is stored.

For the triangle we need one VAO and two VBOs (one VBO for positions and another VBO for colors).

OpenGL will create the VAOs and VBOs for us and will give us back a *handle* or *location* in form of a number.
We need to carefully track these numbers, since we will need them for the actual drawing. 
Furthermore we need to personally deallocate the resources afterwards (much like file handles).

In this tutorial we will use a simple record to store the VAO:

```idris

record Vao where
  constructor MkVao
  id : Int               -- VAO location
  buffers : List Int     -- a list of VBO locations


```

We could have used dependent types here, but remember - this is just the "hello world" and nothing more.

The first thing to do is to create a VAO and *bind* it. Binding *activates* the resource so that we can do things with it.
With OpenGl you will be constantly binding and unbinding things.
The general rule is: if a resource is not bound you cannot use it.

```idris


createBuffers : IO Vao
createBuffers = do
 (vao :: _) <- glGenVertexArrays 1    -- allocate a single VAO 
 glBindVertexArray vao                -- and bind it

```

We now have the location of a VAO. The VAO is bound so we need to create vertex buffer objects to store the position and color data in:

```idris

 (buffer :: colorBuffer :: _) <- glGenBuffers 2  -- create 2 buffers
 glBindBuffer GL_ARRAY_BUFFER buffer             -- bind the position buffer

```

The position data itself now needs to be uploaded to the GPU via the OpenGL API function `glBufferData`. 
This functon wants a *pointer* to the data, so we need to copy the Idris data to a C-Array and pass the pointer to this array to OpenGL:

```idris


 ds <- sizeofDouble               -- here be 'malloc' ...
 ptr <- doublesToBuffer vertices
 glBufferData GL_ARRAY_BUFFER (ds * (cast $ length vertices)) ptr GL_STATIC_DRAW
 free ptr                         -- don't forget this line

```

This is very ugly and no doubt we could improve this code, but did not want to hide all the ugly stuff that 
is happening as it will motivate some functionality in future posts.

Having uploaded the buffer data we need to tell OpenGL what *structure* the data has, in our case
we uploaded a byte array with the following properties:

  - the real data starts at position 0
  - every vertex contains 3 values
  - the components of the vertices are of type `Double`
  - and there is no gap between two vertices

```idris

 glEnableVertexAttribArray 0
 glVertexAttribPointer 0 3 GL_DOUBLE GL_FALSE 0 prim__null

```

For colors we need to do something very similar:

```idris

 glBindBuffer GL_ARRAY_BUFFER colorBuffer   -- bind the color buffer
 ptr2 <- doublesToBuffer colors
 glBufferData GL_ARRAY_BUFFER (ds * (cast $ length colors)) ptr2 GL_STATIC_DRAW
 free ptr2
 glEnableVertexAttribArray 1
 glVertexAttribPointer 1 4 GL_DOUBLE GL_FALSE 0 prim__null 

``` 

With our position and color data now safely on the GPU, we can unbind the VBOs and VAO and return 
the numbers (i.e the locations) OpenGL has given us in our VAO record :

```idris

 glDisableVertexAttribArray 0
 glDisableVertexAttribArray 1
 glBindBuffer GL_ARRAY_BUFFER 0
 glBindVertexArray 0
 pure $ MkVao vao [buffer, colorBuffer]

```

Having provided the data we now need to tell OpenGL how to draw it.

### Shaders

All the actual drawing in OpenGl will be done by scripts that are also uploaded to the GPU.
These scripts are written in a DSL called the "GL Shader Language" (*GLSL*). 
A GLSL programm looks a lot like a C program.

The scripts are called _shaders_ and there are different types of shader for different aspects of the actual rendering.
For the triangle (and most other uses) we will need a _vertex shader_ and a _fragment shader_. 

Multiple shaders will be linked together to form a program. They will be processed in a defined order and the
vertex shader is always the first to be called.

For more information about shaders see [here][5].

This is what our vertex shader looks like:

```GLSL
#version 410 core
 
layout(location=0) in vec3 in_Position;
layout(location=1) in vec4 in_Color;

out vec4 ex_Color;
 
void main(void)
{
  gl_Position = vec4(in_Position, 1.0);
  ex_Color = in_Color;
}

```

The Vertex shader will be called once for each vertex. 
For each call of the vertex shader the variable `in_Position` will be set to the i-th positional vertex (which was a 3-dimensional vector, hence the type `vec3`), and the variable `in_Color`to the corresponding i-th color vertex (a vector of length 4).

As a result the shader will calculate the final position of the vertex, which *must* be a 4-dimensional vertex.
For the triangle we simply return the original unaltered vertex position. 

The vertex color is directly passed on to the fragment shader.

The fragment shader itself looks like this:

```GLSL
#version 410
in vec4 ex_Color;
out vec4 out_Color;
 
void main(void)
{
  out_Color = ex_Color;
}
```

Fragment shaders are responsible for drawing the pixels of each triangle in the VAO. A fragment shader will be called at least once 
for every pixel that needs to be drawn on screen for a triangle.

Since we have only provided per vertex data for colors, OpenGL will interpolate the color values of the triangle corners, which is why
the resulting triangle has pure colors at the corners and blended ones in the middle.

Shaders are provided to OpenGL as strings. Each shader will be compiled and - on successful compilation - linked to final program.
As with the vertex data OpenGL will refer to the shaders using integer handles.

And so we define a data type for shaders handles similarily to the VAO:

```idris

record Shaders where
  constructor MkShaders
  shaders : List Int        -- individual handles of the shaders
  program : Int             -- handle / location of the linked program

```

As with buffers we will allocate a shader before uploading the data:

```idris

createShaders : IO Shaders
createShaders = do
 vertexShader <- glCreateShader GL_VERTEX_SHADER
   
 vtx <- readFile "shaderHelloWorld.vert"                  
 glShaderSource vertexShader 1 [vtx] [(cast $ length vtx)]
 glCompileShader vertexShader                             
 
 fragmentShader <- glCreateShader GL_FRAGMENT_SHADER      
 
 frg <- readFile "shaderHelloWorld.frag"
 glShaderSource fragmentShader 1 [frg] [(cast $ length frg)]
 glCompileShader fragmentShader

```

Remember this is tutorial code. In a real application any number of things might go wrong: a shader source file might be missing, the shader might not compile, etc. We will pretend (for now) that everything will work just fine.

When the shaders are compiled they need to be linked (like a normal C program):

```idris

 program <- glCreateProgram            -- allocate a program location
 glAttachShader program vertexShader   -- attach the shaders 
 glAttachShader program fragmentShader --    to the program
 
 glLinkProgram program                 -- and link the program
 
 printShaderLog vertexShader
 printShaderLog fragmentShader         -- see if something went wrong

```

Hopefully we now have a shader program, and we can finish the set up:


```idris

 glUseProgram 0                        -- unbinds the shader program
 pure $ MkShaders [vertexShader, fragmentShader] program

```

We have now written code to allocate resources on GPU and symmetrically we need code to deallocate
the resources after use.

```idris

destroyShaders : Shaders -> IO ()
destroyShaders (MkShaders shaders program) = do
 glUseProgram 0                             -- unbind the program
 traverse (glDetachShader program) shaders  -- detach each shader
 glDeleteProgram program                    -- delete the program


destroyBuffers : Vao -> IO ()
destroyBuffers (MkVao vao buffers) = do
 glDisableVertexAttribArray 1               
 glDisableVertexAttribArray 0               
 
 glBindBuffer GL_ARRAY_BUFFER 0             -- unbind VBO
 glDeleteBuffers 2 buffers                  -- and delete VBOs
 
 glBindVertexArray 0                        -- unbind the VAO
 
 glDeleteVertexArrays 1 [vao]               -- ... and delete it


```

### Drawing

Whenever we draw some geometry in OpenGL - in our case a single triangle - we need to
bind the VAO containing the mesh data, bind the shader program and tell OpenGL *how*
we would like to draw the vertices.

However that means we need to carry around the VAO and Shader location during the main loop.

```idris

data State = MkState GlfwWindow Vao Shaders

```

OpenGL stores the result of drawing in a *frame buffer*. This frame buffer is not visible. By default
OpenGl uses a *front* buffer that is currently shown and a *back* buffer we draw into.
After drawing we *swap* the buffers and only then can we see any changes.

Before we begin drawing in the back buffer we need to clear any previous drawings, like a erasing a white board.
In OpenGL we do this by drawing the entire buffer using a single *clear color*.


```idris

draw : State -> IO ()
draw (MkState win vao (MkShaders _ prog)) = do
 glClearColor 0 0 0 1                -- set the clear color 
 glClear GL_COLOR_BUFFER_BIT         -- clear the color buffer
 glUseProgram prog                   -- activate the shaders
 glBindVertexArray (id vao)          -- activate the VAO
 glEnableVertexAttribArray 0         -- enable the vertex postion buffer 
 glEnableVertexAttribArray 1         -- enable the color buffer

```

Until now we have only done some state management, bringing OpenGL into a state, that a `draw` command will actually be 
able to draw something.

We can now do the actual drawing:

```idris

 glDrawArrays GL_TRIANGLES 0 3


```

This tells OpenGL to draw three vertices (starting with the zero-th vertex) using the *Triangles* drawing
primitive. The drawing primitive needs to match the vertex data. 
With the triangles primitive, OpenGL draws a triangle out of every three consecutive vertices.
There are other options like *Lines* or *Triangle Strips*, but we won't go into them. 

The only thing left to do is swapping the back and front buffer:

```idris

 glfwSwapBuffers win

```

You will notice that back and front buffer swapping is not done by OpenGL itself but by the GLFW library,
which makes sense, since we essentially are asking the windowing system to display something else and OpenGL
does not deal with displays. 

However: this is it! If you made it so far - congratulation.

You could now try this out by typing:

```bash
$ idris -p glfw -p gl -p contrib -o hello 2015-09-13-hello-world.lidr
$ ./hello
```

The rest of the post deals with the main method, the event loop and the display.

For more details about this part [see here](/programming/graphics/idris/2015/08/24/simple-display.html).


### Appendix A: The rest of the code

```idris

initDisplay : String -> Int -> Int -> IO GlfwWindow
initDisplay title width height = do
  glfw <- glfwInit
  glfwWindowHint GLFW_CONTEXT_VERSION_MAJOR  4
  glfwWindowHint GLFW_CONTEXT_VERSION_MINOR  1
  glfwWindowHint GLFW_OPENGL_FORWARD_COMPAT  1
  glfwWindowHint GLFW_OPENGL_PROFILE         (toInt GLFW_OPENGL_CORE_PROFILE)
  win <- glfwCreateWindow title width height defaultMonitor
  -- now we pretend every thing is going to be ok
  glfwMakeContextCurrent win
  glewInit
  info <- glGetInfo
  putStrLn info
  return win

main : IO ()
main = do win <- initDisplay "Hello Idris" 640 480
          glfwSetInputMode win GLFW_STICKY_KEYS 1
          glfwSwapInterval 0
          shaders <- createShaders
          vao <- createBuffers
          eventLoop $ MkState win vao shaders
          destroyBuffers vao
          destroyShaders shaders
          glfwDestroyWindow win
          glfwTerminate
          pure ()
       where
         eventLoop : State -> IO ()
         eventLoop state@(MkState win vao prog) = do
                      draw state
                      glfwPollEvents
                      key <- glfwGetFunctionKey win GLFW_KEY_ESCAPE
                      shouldClose <- glfwWindowShouldClose win
                      if shouldClose || key == GLFW_PRESS
                      then pure ()
                      else do
                        eventLoop state





