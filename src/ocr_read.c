/* O OCR do Windows chamado de C: pixels BGRA viram um SoftwareBitmap, o motor de OCR do
 * idioma do usuário — ou, sem ele, o primeiro idioma de OCR instalado — o lê, e as linhas
 * reconhecidas voltam juntas por quebras de linha. O OcrResult.Text juntaria as linhas por
 * espaço, e as quebras são justamente o que o popup pergunta se ficam. Incluído por ocr.v. */
#include "ocr_winrt.h"
#include <stdlib.h>
#include <string.h>

/* Falha própria desta leitura: o Windows não tem nenhum idioma de OCR instalado. */
#define VSHOT_OCR_NO_LANGUAGE ((HRESULT)0xA0000001L)

#define VSHOT_TRY(call) do { hr = (call); if (FAILED(hr)) goto done; } while (0)
#define VSHOT_RELEASE(p) do { if (p) { (p)->lpVtbl->Release(p); (p) = NULL; } } while (0)

static HRESULT vshot_factory(PCWSTR name, REFIID iid, void **out) {
    HSTRING_HEADER header;
    HSTRING string;
    HRESULT hr = WindowsCreateStringReference(name, (UINT32)wcslen(name), &header, &string);
    return FAILED(hr) ? hr : RoGetActivationFactory(string, iid, out);
}

/* O motor do idioma do perfil do usuário; sem OCR para ele, o do primeiro idioma instalado. */
static HRESULT vshot_engine(__x_ABI_CWindows_CMedia_COcr_CIOcrEngine **engine) {
    __x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics *statics = NULL;
    __FIVectorView_1_Windows__CGlobalization__CLanguage *languages = NULL;
    __x_ABI_CWindows_CGlobalization_CILanguage *language = NULL;
    UINT32 count = 0;
    HRESULT hr;
    *engine = NULL;
    VSHOT_TRY(vshot_factory(L"Windows.Media.Ocr.OcrEngine", &IID_VShot_IOcrEngineStatics, (void **)&statics));
    VSHOT_TRY(statics->lpVtbl->TryCreateFromUserProfileLanguages(statics, engine));
    if (*engine) goto done;
    VSHOT_TRY(statics->lpVtbl->get_AvailableRecognizerLanguages(statics, &languages));
    VSHOT_TRY(languages->lpVtbl->get_Size(languages, &count));
    if (count == 0) { hr = VSHOT_OCR_NO_LANGUAGE; goto done; }
    VSHOT_TRY(languages->lpVtbl->GetAt(languages, 0, &language));
    VSHOT_TRY(statics->lpVtbl->TryCreateFromLanguage(statics, language, engine));
    if (!*engine) hr = VSHOT_OCR_NO_LANGUAGE;
done:
    VSHOT_RELEASE(language);
    VSHOT_RELEASE(languages);
    VSHOT_RELEASE(statics);
    return hr;
}

/* Os pixels BGRA, de cima para baixo, como SoftwareBitmap. O quarto byte é ignorado. */
static HRESULT vshot_bitmap(const BYTE *pixels, int width, int height, __x_ABI_CWindows_CGraphics_CImaging_CISoftwareBitmap **bitmap) {
    __x_ABI_CWindows_CSecurity_CCryptography_CICryptographicBufferStatics *buffers = NULL;
    __x_ABI_CWindows_CGraphics_CImaging_CISoftwareBitmapStatics *bitmaps = NULL;
    __x_ABI_CWindows_CStorage_CStreams_CIBuffer *buffer = NULL;
    HRESULT hr;
    VSHOT_TRY(vshot_factory(L"Windows.Security.Cryptography.CryptographicBuffer", &IID_VShot_ICryptographicBufferStatics, (void **)&buffers));
    VSHOT_TRY(buffers->lpVtbl->CreateFromByteArray(buffers, (UINT32)width * (UINT32)height * 4, (BYTE *)pixels, &buffer));
    VSHOT_TRY(vshot_factory(L"Windows.Graphics.Imaging.SoftwareBitmap", &IID_VShot_ISoftwareBitmapStatics, (void **)&bitmaps));
    VSHOT_TRY(bitmaps->lpVtbl->CreateCopyWithAlphaFromBuffer(bitmaps, buffer, BitmapPixelFormat_Bgra8, width, height, BitmapAlphaMode_Ignore, bitmap));
done:
    VSHOT_RELEASE(buffer);
    VSHOT_RELEASE(bitmaps);
    VSHOT_RELEASE(buffers);
    return hr;
}

/* Espera a leitura terminar. Os objetos do OCR são ágeis, e consultar o estado com uma
 * pausa curta não trava a thread da interface: numa área comum são dezenas de milissegundos. */
static HRESULT vshot_wait(__FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult *operation, __x_ABI_CWindows_CMedia_COcr_CIOcrResult **result) {
    IAsyncInfo *info = NULL;
    AsyncStatus status = Started;
    HRESULT hr;
    VSHOT_TRY(operation->lpVtbl->QueryInterface(operation, &IID_VShot_IAsyncInfo, (void **)&info));
    while (SUCCEEDED(hr = info->lpVtbl->get_Status(info, &status)) && status == Started) Sleep(5);
    if (FAILED(hr)) goto done;
    if (status != Completed) {
        info->lpVtbl->get_ErrorCode(info, &hr);
        if (SUCCEEDED(hr)) hr = E_FAIL;
        goto done;
    }
    VSHOT_TRY(operation->lpVtbl->GetResults(operation, result));
done:
    VSHOT_RELEASE(info);
    return hr;
}

/* Acrescenta um texto do Windows ao fim do buffer, que cresce quando precisa. */
static int vshot_append(wchar_t **text, size_t *length, size_t *capacity, PCWSTR piece, UINT32 size) {
    if (*length + size + 2 > *capacity) {
        size_t grown = (*length + size + 2) * 2;
        wchar_t *bigger = realloc(*text, grown * sizeof(wchar_t));
        if (!bigger) return 0;
        *text = bigger;
        *capacity = grown;
    }
    memcpy(*text + *length, piece, size * sizeof(wchar_t));
    *length += size;
    (*text)[*length] = 0;
    return 1;
}

/* As linhas do resultado, uma por linha do texto. */
static HRESULT vshot_lines(__x_ABI_CWindows_CMedia_COcr_CIOcrResult *result, wchar_t **text) {
    __FIVectorView_1_Windows__CMedia__COcr__COcrLine *lines = NULL;
    size_t length = 0, capacity = 0;
    UINT32 count = 0;
    HRESULT hr;
    *text = calloc(1, sizeof(wchar_t));
    if (!*text) return E_OUTOFMEMORY;
    VSHOT_TRY(result->lpVtbl->get_Lines(result, &lines));
    VSHOT_TRY(lines->lpVtbl->get_Size(lines, &count));
    for (UINT32 index = 0; index < count; index++) {
        __x_ABI_CWindows_CMedia_COcr_CIOcrLine *line = NULL;
        HSTRING string = NULL;
        UINT32 size = 0;
        VSHOT_TRY(lines->lpVtbl->GetAt(lines, index, &line));
        hr = line->lpVtbl->get_Text(line, &string);
        VSHOT_RELEASE(line);
        if (FAILED(hr)) goto done;
        PCWSTR raw = WindowsGetStringRawBuffer(string, &size);
        int ok = (index == 0 || vshot_append(text, &length, &capacity, L"\n", 1)) && vshot_append(text, &length, &capacity, raw, size);
        WindowsDeleteString(string);
        if (!ok) { hr = E_OUTOFMEMORY; goto done; }
    }
done:
    VSHOT_RELEASE(lines);
    if (FAILED(hr)) { free(*text); *text = NULL; }
    return hr;
}

/* vshot_read_text lê o texto dos pixels BGRA. Devolve o texto, alocado com malloc, ou NULL
 * com o HRESULT da falha em *failure, que é um int porque é o que o V passa. */
static wchar_t *vshot_read_text(const BYTE *pixels, int width, int height, int *failure) {
    __x_ABI_CWindows_CGraphics_CImaging_CISoftwareBitmap *bitmap = NULL;
    __x_ABI_CWindows_CMedia_COcr_CIOcrEngine *engine = NULL;
    __FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult *operation = NULL;
    __x_ABI_CWindows_CMedia_COcr_CIOcrResult *result = NULL;
    wchar_t *text = NULL;
    /* Numa thread que já tem apartamento de outro tipo o Windows Runtime continua usável;
     * só quem iniciou devolve. */
    HRESULT started = RoInitialize(RO_INIT_SINGLETHREADED);
    HRESULT hr;
    VSHOT_TRY(vshot_engine(&engine));
    VSHOT_TRY(vshot_bitmap(pixels, width, height, &bitmap));
    VSHOT_TRY(engine->lpVtbl->RecognizeAsync(engine, bitmap, &operation));
    VSHOT_TRY(vshot_wait(operation, &result));
    VSHOT_TRY(vshot_lines(result, &text));
done:
    VSHOT_RELEASE(result);
    VSHOT_RELEASE(operation);
    VSHOT_RELEASE(bitmap);
    VSHOT_RELEASE(engine);
    if (SUCCEEDED(started)) RoUninitialize();
    *failure = (int)hr;
    return text;
}
