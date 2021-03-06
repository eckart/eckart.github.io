---
layout: post
title:  "Open a Display for OpenGL using Idris"
date:   2015-08-24 22:00:01
categories: Programming Graphics Idris
---

This post shows how to open a display with an OpenGL context from
the [Idris](http://www.idris-lang.org) programming language.

In and of itself this is not very interesting.
In fact this is just a simple preface for other post that will be
more concerned with the bindings for OpenGL itself.

The OpenGL-API knows nothing about handling displays or even user input, so we need a separate library for this.

There are several ways to create displays and OpenGL contexts.
For this post we will be using the [GLFW](http://www.glfw.org) library.


Luckily there is an Idris binding for GLFW (written by me, ahem), that is just functional
enough to open displays and handle keyboard events. You can find it here: [https://github.com/eckart/glfw-idris](https://github.com/eckart/glfw-idris)

So, to open a display we will need an idris module and import the GLFW binding:

```idris

> module Main
>
> import Graphics.Util.Glfw

```

We can now write a small helper function to initialise GLFW and open a window.
But before we actually open the window we can give GLFW hints what kind of OpenGl context it should provide.
In my case, since I am on a macbook, I need to request an OpenGL context
for the 4.1 core API.

```idris

> initDisplay : String -> Int -> Int -> IO GlfwWindow
> initDisplay title width height = do
>   glfw <- glfwInit
>   glfwWindowHint GLFW_CONTEXT_VERSION_MAJOR  4
>   glfwWindowHint GLFW_CONTEXT_VERSION_MINOR  1
>   glfwWindowHint GLFW_OPENGL_FORWARD_COMPAT  1
>   glfwWindowHint GLFW_OPENGL_PROFILE         (toInt GLFW_OPENGL_CORE_PROFILE)

```
We will not actually be using this context in this post, but there will be a follow up where we do need it.

Now we can actually create the window:

```idris

>
>   win <- glfwCreateWindow title width height defaultMonitor
>   glfwMakeContextCurrent win
>   return win

```

And that's it. We are now going to use this helper function in the main function:

```idris

> main : IO ()
> main = do win <- initDisplay "Hello Idris" 640 480
>           glfwSetInputMode win GLFW_STICKY_KEYS 1

```
Having created the window we need to enable the _sticky_ mode on the window.
The sticky mode retains the events until we query them in the main loop.
Another option would be to register callbacks, but the idris foreign function
interface for C currently does not support callbacks.

Now we can start the main loop. When the main loop has finished we simply
need to cleanup some resources and we're good.

```idris

>
>           eventLoop win 0
>           glfwDestroyWindow win
>           glfwTerminate
>           pure ()

```

The main loop itself is not very interesting yet
We poll the events, check whether we should close and either close or keep running.

```idris

>        where
>          eventLoop : GlfwWindow -> Int -> IO ()
>          eventLoop win ticks = do
>                       glfwPollEvents
>                       key <- glfwGetFunctionKey win GLFW_KEY_ESCAPE
>                       shouldClose <- glfwWindowShouldClose win
>                       if shouldClose || key == GLFW_PRESS
>                       then pure ()
>                       else do
>                         eventLoop win (ticks+1)

```
And that's it.

This post is actually a literate idris file and you can find the [source code](https://github.com/eckart/eckart.github.io/blob/master/_lidr/opengl/2015-08-24-simple-display.lidr)
on github.

If you want to run it you will need to install some libraries

* Idris itself 
* GLFW 
* pkg-config
* Idris GLFW bindings



You can compile and run the code by entering the followin two commands in a terminal,
provided you have installed all the requirements.

```bash
$ idris -p glfw -o display 2015-08-24-simple-display.lidr
$ ./display
```

And then you will see this:

![Simple Display](/assets/images/simple-display.png)

Beautiful, isn't it?
