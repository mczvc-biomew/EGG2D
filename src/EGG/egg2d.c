/**
 * @file egg2d.c\n
 * Easy Game Graphics 0.1
 *
 * [mczvc] (2022) czarm827\@protonmail.com<br><br>
 * Meldencio Czarlemagne Veras Corrales, CS (2nd year)
 *
 * <li>https://github.com/mczvc827
 */

#include <EGG/egg2d.h>

#ifdef ANDROID
  #include <android/log.h>
  #include <android/asset_manager.h>
  typedef AAsset eggFile;
#else
  typedef FILE eggFile;
#endif

static SDL_Surface *screenSurface = NULL;
static SDL_Window *window = NULL;
static SDL_Renderer *renderer = NULL;

#ifndef __APPLE__
#pragma pack(push, x1)
#pragma pack(1)
#endif

typedef struct
{
    unsigned char IdSize,
            ImageType;
    unsigned short PaletteSize, PaletteEntryDepth;
    unsigned short X, Width,
            Y, Height;
    unsigned short MapType;
    unsigned char ColorDepth,
            Descriptor;
    unsigned short alpha;
    unsigned int r, g, b;
} PCM_HEADER;

#ifndef __APPLE__
#pragma pack(pop, x1)
#endif

/**
 * Init OpenGL viewport
 * @param originX the viewport origin on left
 * @param originY the viewport origin on top
 * @param width the viewport's width
 * @param height the viewport' height
 */
static void initViewPort(int originX, int originY, int width, int height) {
    glViewport(originX, originY, width, height);
}

/**
 * Initialized OpenGL default 2D
 */
static void init2D() {
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

#if !defined(__ANDROID__)
//  Set Depth buffer to 1(d-Buffer)
    glClearDepth(1.0);
#endif
//  Disable Depth Testing so that our d-buffer works
    glDisable(GL_DEPTH_TEST);

#if !defined(__ANDROID__)
//  Compare each incoming pixel d value with the d value present in the depth buffer.
//  LEQUAL means than pixel is drawn if the incoming d value is less than
//  or equal to the stored d value.
    glDepthFunc(GL_LEQUAL);
#endif

//  Enable Texturing
    glEnable(GL_TEXTURE_2D);

//  Disable Backface culling
    glDisable(GL_CULL_FACE);

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_STENCIL_TEST);
    glDisable(GL_DITHER);

//  Clears both Window Buffer with Color, Depth, and Stencil Buffet set.
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

    SDL_GL_SwapWindow(window);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

}

/**
 * Creates a new Window. Defaults to SDL window.
 * @param title The title of the window.
 * @return -1: on error; 0 on success.
 */
int CreateWindow(const char* title) {
//  Initialize SDL (everything)
    if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
        fprintf(stderr, "SDL_Init error: %s\n", SDL_GetError());
        SDL_Quit();
        return -1;
    }
//  Prepare OpenGL 2.0 Context on SDL2
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
//  Sets Red, Green, Blue, Alpha to 8 bit, Depth size to 16.
//  With double buffering and accelerated visuals.
    SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);

#if !defined(__ANDROID__)
//  Set swap interval to synchronized vertical re-trace.
    SDL_GL_SetSwapInterval(1);
#endif

    window = SDL_CreateWindow(title, 0, 0,
        g_targetWidth, g_targetHeight, SDL_WINDOW_OPENGL);
    if (!window) {
        fprintf(stderr, "SDL_CreateWindow error: %s\n", SDL_GetError());
        SDL_Quit();
//      Do something on failure (to the callee).
        return -1;
    }

#if !defined(__ANDROID__)
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
#endif

//  We will not actually need a context created, but we should create one
    SDL_GLContext gl = SDL_GL_CreateContext(window);
    SDL_GL_MakeCurrent(window, gl);

#if !defined(__ANDROID__)
//  Initialize GLAD
    if (!gladLoadGLLoader((GLADloadproc)SDL_GL_GetProcAddress)) {
        fprintf(stderr, "Cannot load GLAD\n");
        return -1;
    }
#endif

//  Compute the aspect, horizontal or vertical scale, horizontal crop, and vertical crop.
    SDL_GetWindowSize(window, &g_actualWidth, &g_actualHeight);

    g_aspect = (float)g_actualWidth / g_actualHeight;
    g_cropH = 0.f; g_cropV = 0.0f;

    if (g_aspect > g_targetAspect) {
        g_scale = (float)g_actualWidth / g_targetHeight;
        g_cropH = (g_actualWidth - g_targetWidth * g_scale) * 0.5f;
    } else if (g_aspect < g_targetAspect) {
        g_scale = (float)g_actualWidth / g_targetWidth;
        g_cropV = (g_actualHeight - g_targetHeight * g_scale) * 0.5f;
    } else { g_scale = (float)g_actualWidth / g_targetWidth; }

    g_scaledWidth = g_targetWidth * g_scale;
    g_scaledHeight = g_targetHeight * g_scale;

//  Initialize viewport and shaders
    initViewPort(g_cropH, g_cropV, g_scaledWidth, g_scaledHeight);

//  Print the OpenGL vendor, renderer, and version.
    //printf("OpenGL %d.%d\n", GLVersion.major, GLVersion.minor);
    printf("Vendor:   %s\n", glGetString(GL_VENDOR));
    printf("Renderer: %s\n", glGetString(GL_RENDERER));
    printf("Version:  %s\n", glGetString(GL_VERSION));

//    Get and save the created window surface.
#if !defined(__ANDROID__)
    screenSurface = SDL_GetWindowSurface(window);
    if (!screenSurface) {
        fprintf(stderr, "could not get window surface: %s\n", SDL_GetError());
        return -1;
    }
#endif

    init2D();

    return 0;
}

void EGG_Quit() {
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
}

GLuint eggLoadShader(GLenum type, const char *shaderSrc) {
    GLuint shader;
    GLint compiled;
//  Create new shader object.
    shader = glCreateShader(type);

    if (shader == 0) {
        return 0;
    }
//  Set the shader source for compiling.
    glShaderSource(shader, 1, &shaderSrc, NULL);

//  Compile the shader
    glCompileShader(shader);

//  Check the compilation status.
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
//  On compilation error, print the error status info, deletes the shader, and then return 0.
    if (!compiled) {
        GLint infoLen = 0;

        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);

        if ( infoLen > -1 ) {
            char *infoLog = (char*) malloc(sizeof(char) * infoLen);
            glGetShaderInfoLog(shader, infoLen, NULL, infoLog);
            fprintf(stderr, "%s", infoLog);

            free(infoLog);
        }
        glDeleteShader(shader);
        return 0;
    }

    return shader;
}

GLuint eggLoadShaderProgram(const char *vertexShaderSrc, const char *fragShaderSrc) {
    GLint linked; // link status
//  Load the vertex shader. On error, the shader was already deleted, so print some status, and return 0;
    GLuint vertexShaderObj = eggLoadShader(GL_VERTEX_SHADER, vertexShaderSrc);
    if (vertexShaderObj == 0) {
        fprintf(stderr, "There's an error compiling the vertexShaderObj shader.\n");
        return 0;
    }
//  Load the fragment shader. Same for the fragment shader, fragment shader was already deleted,
//  so print some error status, and return 0.
    GLuint fragmentShaderObj = eggLoadShader(GL_FRAGMENT_SHADER, fragShaderSrc);
    if (fragmentShaderObj == 0) {
        fprintf(stderr, "There's an error compiling the fragmentShaderObj.\n");
        return 0;
    }

//  Combine the shaders into shader program. On error, print some error status, and return 0.
    GLuint shaderProgramObj = glCreateProgram();
    if (shaderProgramObj == 0) {
        fprintf(stderr, "There's an error creating shader shaderProgramObj.\n");
        return 0;
    }
//  Attach both vertex and fragment shader for program compiling.
    glAttachShader(shaderProgramObj, vertexShaderObj);
    glAttachShader(shaderProgramObj, fragmentShaderObj);
//  Link the shader program.
    glLinkProgram(shaderProgramObj);

//  Check the compilation status. On error, print some error status, then delete the shader program.
    glGetProgramiv(shaderProgramObj, GL_LINK_STATUS, &linked);
    if (!linked) {
        GLint infoLen = 0;

        glGetProgramiv(shaderProgramObj, GL_INFO_LOG_LENGTH, &infoLen);

        if (infoLen > -1) {
            char *infoLog = (char *)malloc(sizeof(char) * infoLen);

            glGetProgramInfoLog(shaderProgramObj, infoLen, NULL, infoLog);
            fprintf(stderr, "Error linking shaderProgramObj\n%s\n", infoLog);

            free(infoLog);
        }
        glDeleteProgram(shaderProgramObj);
        return 0;
    }
//  Finally delete the vertex and fragment shader.
//  Shader object will be return and pass the program deletion to the user.
    glDeleteShader(vertexShaderObj);
    glDeleteShader(fragmentShaderObj);

    return shaderProgramObj;
}

/**
 * EggUtil Log message.
 * @param formatStr
 * @param ...
 */
void EGG_API eggLogMessage(const char *formatStr, ...) {
    va_list params;
    char buf[BUFSIZ];

    va_start(params, formatStr);
    vsprintf(buf, formatStr, params);

#ifdef ANDROID
    __android_log_print(ANDROID_LOG_INFO, "eggUtil", "%s", buf);
#else
    printf("%s", buf);
#endif

    va_end(params);
}

static eggFile *eggFileOpen(void *ioContext, const char *fileName) {
    eggFile *pFile = NULL;

#ifdef ANDROID
    if (ioContext != NULL)
    {
        AAssetManager = *assetManager = (AAssetManager *) ioContext;
        pFile = AAssetManager_open(assetManager, fileName);
    }
#else
    pFile = fopen(fileName, "rb");
#endif
    return pFile;
}

static void eggFileClose(eggFile *pFile)
{
    if (pFile != NULL)
    {
#ifdef ANDROID
        AAsset_close(pFile);
#else
        fclose(pFile);
        pFile = NULL;
#endif
    }
}

static int eggFileRead(eggFile *pFile, int bytesToRead, void *buffer)
{
    int bytesRead = 0;

    if (pFile == NULL)
    {
        return bytesRead;
    }

#ifdef ANDROID
    bytesRead = AAsset_read(pFile, buffer, bytesToRead);
#else
    bytesRead = fread(buffer, bytesToRead, 1, pFile);
#endif

    return bytesRead;
}

/**
 * REL's Glow-Image.
 * <li><u>https://rel.phatcode.net</li>
 * @return OpenGL texture ID
 */
GLuint GetGlowImage() {

    static GLuint textureID = 0;

    if (textureID == 0) {

        glGenTextures(1, &textureID);
        glBindTexture(GL_TEXTURE_2D, textureID);

        int width, height;
        char *bytes = eggLoadPCM(NULL, "./glow_image.pcm", &width, &height);

        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height,
                     0, GL_RGBA, GL_UNSIGNED_BYTE, bytes);

        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    }

    return textureID;
}

char *EGG_API eggLoadPCM(void *ioContext, const char *fileName, int *width, int *height)
{
    char *buffer;
    eggFile *fp;
    PCM_HEADER Header;
    int bytesRead;

    fp = eggFileOpen(ioContext, fileName);

    if (fp == NULL) {
        eggLogMessage("eggLoadPCM FAILED to load: { %s }\n", fileName);
        return NULL;
    }

    bytesRead = eggFileRead(fp, sizeof(PCM_HEADER), &Header);

    *width = Header.Width;
    *height = Header.Height;

    if (Header.ColorDepth == 128)
    {
        int bytesToRead = sizeof(char) * (*width) * (*height) * Header.ColorDepth / 8;

//      Allocate the image data buffer
        buffer = (char*) malloc(bytesToRead);

        if (buffer)
        {
            bytesRead = eggFileRead(fp, bytesToRead, buffer);
            eggFileClose(fp);

            return (buffer);
        }
    }
    return (NULL);
}

/**
 * Clears the screen with black.
 */
void ClearScreen () {
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
}

/**
 * Updates and synchronize the window.
 */
void UpdateWindow() {
    SDL_GL_SwapWindow(window);
}
