---
layout: post
title:  "Hello World with Idris and OpenGL"
date:   2015-08-24 22:00:01
categories: Programming, Graphics, Idris
---

Some time ago I decided to simultaneously learn [Idris](https://github.com/idris-lang/Idris-dev) and 3D graphics programming.

(Intro: what this is and what it is not, links to openGl tutorials)

(Installation and running instructions, link to source)
```idris

> module Main

```

(Something about the modules involved)
```idris 

> import Graphics.Rendering.Gl
> import Graphics.Rendering.Config
> import Data.Floats

```

(why do we need GLFW and what alternatives are there)
```idris 

> import Graphics.Util.Glfw

```

(why this include is necessary)
```idris 

> %include C "GL/glew.h"
> %flag C "-Wno-pointer-sign"

```
### working with vertex data

(a word about vertices + triangles)
```idris 

> vertices : List Double
> vertices = [
>   -0.8, -0.8,  0.0,
>    0.0,  0.8,  0.0,
>    0.8, -0.8,  0.0
>   ]

```

(about the colors
```idris 

> colors : List Double
> colors = [
>    1.0, 0.0, 0.0, 1.0,
>    0.0, 1.0, 0.0, 1.0,
>    0.0, 0.0, 1.0, 1.0
>   ]

```

(loading data to the GPU - part 1 VAOs + VBOs)
```idris

> record Vao where
>   constructor MkVao
>   id : Int
>   buffers : List Int
> 
> 
> createBuffers : IO Vao
> createBuffers = do
>  (vao :: _) <- glGenVertexArrays 1
>  glBindVertexArray vao

```

(uploading the positions and colors)
```idris

>  (buffer :: colorBuffer :: _) <- glGenBuffers 2
>  glBindBuffer GL_ARRAY_BUFFER buffer
>  ds <- sizeofDouble
>  ptr <- doublesToBuffer vertices
>  glBufferData GL_ARRAY_BUFFER (ds * (cast $ length vertices)) ptr GL_STATIC_DRAW
>  free ptr

```

(telling opengl what structure the data has)
```idris

>  glEnableVertexAttribArray 0
>  glVertexAttribPointer 0 3 GL_DOUBLE GL_FALSE 0 prim__null

```

and doing the same with colors
```idris

>  glBindBuffer GL_ARRAY_BUFFER colorBuffer
>
>  ptr2 <- doublesToBuffer colors
>  glBufferData GL_ARRAY_BUFFER (ds * (cast $ length colors)) ptr2 GL_STATIC_DRAW
>  free ptr2
>
>  glEnableVertexAttribArray 1
>  glVertexAttribPointer 1 4 GL_DOUBLE GL_FALSE 0 prim__null

``` 


```idris

>  glDisableVertexAttribArray 0
>  glDisableVertexAttribArray 1
>  glBindBuffer GL_ARRAY_BUFFER 0
>  glBindVertexArray 0
>
>  pure $ MkVao vao [buffer, colorBuffer]

```

### Shaders

(the vertex shader)

```GLSL
#version 410 core
 
layout(location=0) in vec4 in_Position;
layout(location=1) in vec4 in_Color;

out vec4 ex_Color;
 
void main(void)
{
  gl_Position = vec4(in_Position, 1.0);
  ex_Color = in_Color;
}

```

(the fragment shader)
```GLSL
#version 410
in vec4 ex_Color;
out vec4 out_Color;
 
void main(void)
{
  out_Color = ex_Color;
}
```


```idris

> record Shaders where
>   constructor MkShaders
>   shaders : List Int
>   program : Int

```


```idris

> createShaders : IO Shaders
> createShaders = do
>  vertexShader <- glCreateShader GL_VERTEX_SHADER
>
>  vtx <- readFile "shaderHelloWorld.vert"
>  glShaderSource vertexShader 1 [vtx] [(cast $ length vtx)]
>  glCompileShader vertexShader
>
>  fragmentShader <- glCreateShader GL_FRAGMENT_SHADER
>
>  frg <- readFile "shaderHelloWorld.frag"
>  glShaderSource fragmentShader 1 [frg] [(cast $ length frg)]
>  glCompileShader fragmentShader
>

```

```idris

>  program <- glCreateProgram
>  glAttachShader program vertexShader
>  glAttachShader program fragmentShader
>
>  glLinkProgram program
>
>  printShaderLog vertexShader
>  printShaderLog fragmentShader

```

```idris

>  glUseProgram 0
>  pure $ MkShaders [vertexShader, fragmentShader] program

```


```idris

> destroyShaders : Shaders -> IO ()
> destroyShaders (MkShaders shaders program) = do
>  glUseProgram 0
>  traverse (glDetachShader program) shaders
>  glDeleteProgram program

```


```idris

> destroyBuffers : Vao -> IO ()
> destroyBuffers (MkVao vao buffers) = do
>  glDisableVertexAttribArray 1
>  glDisableVertexAttribArray 0
>
>  glBindBuffer GL_ARRAY_BUFFER 0
>  glDeleteBuffers 2 buffers
>
>  glBindVertexArray 0
>
>  glDeleteVertexArrays 1 [vao]


```

(the State for looping)
```idris

> data State = MkState GlfwWindow Vao Shaders

```idris

> draw : State -> IO ()
> draw (MkState win vao (MkShaders _ prog)) = do
>                   glClearColor 0 0 0 1
>                   glClear GL_COLOR_BUFFER_BIT
>                   glUseProgram prog
>                   glBindVertexArray (id vao)
>                   glEnableVertexAttribArray 0
>                   glEnableVertexAttribArray 1
>

```
(drawing + primitives)
```idris

>                   glDrawArrays GL_TRIANGLES 0 3


```
(swapping the buffer)
```idris

>                   glfwSwapBuffers win

```


and we're good.


This is rest of the code. For a detailed description see (other post)

```idris

> initDisplay : String -> Int -> Int -> IO GlfwWindow
> initDisplay title width height = do
>   glfw <- glfwInit
>   glfwWindowHint GLFW_CONTEXT_VERSION_MAJOR  4
>   glfwWindowHint GLFW_CONTEXT_VERSION_MINOR  1
>   glfwWindowHint GLFW_OPENGL_FORWARD_COMPAT  1
>   glfwWindowHint GLFW_OPENGL_PROFILE         (toInt GLFW_OPENGL_CORE_PROFILE)
>   win <- glfwCreateWindow title width height defaultMonitor
>   -- now we pretend every thing is going to be ok
>   glfwMakeContextCurrent win
>   glewInit
>   info <- glGetInfo
>   putStrLn info
>   return win

> main : IO ()
> main = do win <- initDisplay "Hello Idris" 640 480
>           glfwSetInputMode win GLFW_STICKY_KEYS 1
>           glfwSwapInterval 0
>           shaders <- createShaders
>           vao <- createBuffers
>           eventLoop $ MkState win vao shaders
>           destroyBuffers vao
>           destroyShaders shaders
>           glfwDestroyWindow win
>           glfwTerminate
>           pure ()
>        where
>          eventLoop : State -> IO ()
>          eventLoop state@(MkState win vao prog) = do
>                       draw state
>                       glfwPollEvents
>                       key <- glfwGetFunctionKey win GLFW_KEY_ESCAPE
>                       shouldClose <- glfwWindowShouldClose win
>                       if shouldClose || key == GLFW_PRESS
>                       then pure ()
>                       else do
>                         eventLoop state


execute this by 

```bash
$ idris -p glfw -p gl -p contrib -o hello hello-world.lidr
$ ./hello
```
