#ifndef EGG_H_INCLUDED
/**
 * @file egg2d.h\n
 * Easy Game Graphics 0.1
 *
 * [mczvc] (2022) czarm827\@protonmail.com<br><br>
 * Meldencio Czarlemagne Veras Corrales, CS (2nd year)
 *
 * <li>https://github.com/mczvc827
 */
#define EGG_H_INCLUDED

#include <stdio.h>
#include <math.h>
#include <SDL2/SDL.h>
#if defined(__ANDROID__) && defined(GLES2)
  #include <GLES2/gl2.h>
#elif defined(__ANDROID__) && defined(GLES1)
  #include <GLES/gl.h>
#else
  #include <glad/glad.h>
#endif
#ifdef __cplusplus

extern "C" {
#endif

//  Macros

#ifdef WIN32
#define EGG_API __cdecl
#else
#define EGG_API
#endif

#define GL_CHECK(x) \
    x;              \
    {               \
        GLenum glError = glGetError(); \
        if(glError != GL_NO_ERROR) {   \
            SDL_Log("glGetError() = %i (0x%.8x) at line %i\n", glError, glError, __LINE__); \
        }           \
    }

extern int g_targetWidth, g_targetHeight;
extern double g_targetAspect;

static int g_actualWidth, g_actualHeight;
static int g_aspect;
static int g_scale;
static int g_scaledWidth, g_scaledHeight;
static int g_cropH, g_cropV;

int CreateWindow(const char *title);

void ClearScreen();

GLuint eggLoadShader(GLenum type, const char *shaderSrc);

GLuint eggLoadShaderProgram(const char *vertexShaderSrc, const char *fragShaderSrc);

void EGG_API eggLogMessage(const char *formatStr, ...);

char *EGG_API eggLoadPCM(void *ioContext, const char *fileName, int *width, int *height);

GLuint GetGlowImage();

void UpdateWindow();
void EGG_Quit();

#ifdef __cplusplus
}
#endif

#endif