/* Declarações C mínimas de Windows.Media.Ocr (o MinGW-w64 não traz windows.media.ocr.h).
   Ordem de vtable e IIDs conferidos contra Windows SDK 10.0.26100.0 (winrt/windows.media.ocr.idl)
   e contra C:\Windows\System32\WinMetadata\Windows.Media.winmd (reflexão .NET).
   Os IIDs parametrizados foram recalculados pelo algoritmo pinterface (SHA-1) do WinRT. */
#ifndef VSHOT_OCR_WINRT_H
#define VSHOT_OCR_WINRT_H

#include <windows.h>
#include <roapi.h>
#include <winstring.h>
/* O asyncinfo.h chama um dos estados da operação de Error, o mesmo nome do tipo de erro que o
   C gerado pelo V já declarou quando este cabeçalho entra. Renomeado só durante as inclusões,
   o estado passa a se chamar VShot_AsyncError, e o Error do V fica intacto. */
#define Error VShot_AsyncError
#include <asyncinfo.h>
#include <windows.globalization.h>      /* ILanguage, ILanguageFactory, IVectorView<Language> */
#include <windows.graphics.imaging.h>   /* ISoftwareBitmap, ISoftwareBitmapStatics, BitmapPixelFormat */
#include <windows.security.cryptography.h> /* ICryptographicBufferStatics (IBuffer a partir de bytes) */
#undef Error

#ifndef __windows_media_ocr_h__

typedef struct __x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics __x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics;
typedef struct __x_ABI_CWindows_CMedia_COcr_CIOcrEngine __x_ABI_CWindows_CMedia_COcr_CIOcrEngine;
typedef struct __x_ABI_CWindows_CMedia_COcr_CIOcrResult __x_ABI_CWindows_CMedia_COcr_CIOcrResult;
typedef struct __x_ABI_CWindows_CMedia_COcr_CIOcrLine __x_ABI_CWindows_CMedia_COcr_CIOcrLine;
typedef struct __FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult __FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult;
typedef struct __FIVectorView_1_Windows__CMedia__COcr__COcrLine __FIVectorView_1_Windows__CMedia__COcr__COcrLine;

/* 5BFFA85A-3384-3540-9940-699120D428A8 */
static const IID IID_VShot_IOcrEngineStatics = {0x5bffa85a, 0x3384, 0x3540, {0x99,0x40, 0x69,0x91,0x20,0xd4,0x28,0xa8}};
/* 5A14BC41-5B76-3140-B680-8825562683AC */
static const IID IID_VShot_IOcrEngine = {0x5a14bc41, 0x5b76, 0x3140, {0xb6,0x80, 0x88,0x25,0x56,0x26,0x83,0xac}};
/* 9BD235B2-175B-3D6A-92E2-388C206E2F63 */
static const IID IID_VShot_IOcrResult = {0x9bd235b2, 0x175b, 0x3d6a, {0x92,0xe2, 0x38,0x8c,0x20,0x6e,0x2f,0x63}};
/* 0043A16F-E31F-3A24-899C-D444BD088124 */
static const IID IID_VShot_IOcrLine = {0x0043a16f, 0xe31f, 0x3a24, {0x89,0x9c, 0xd4,0x44,0xbd,0x08,0x81,0x24}};
/* IAsyncOperation<OcrResult>: C7D7118E-AE36-59C0-AC76-7BADEE711C8B */
static const IID IID_VShot_IAsyncOperation_OcrResult = {0xc7d7118e, 0xae36, 0x59c0, {0xac,0x76, 0x7b,0xad,0xee,0x71,0x1c,0x8b}};
/* IVectorView<OcrLine>: 60C76EAC-8875-5DDB-A19B-65A3936279EA */
static const IID IID_VShot_IVectorView_OcrLine = {0x60c76eac, 0x8875, 0x5ddb, {0xa1,0x9b, 0x65,0xa3,0x93,0x62,0x79,0xea}};

#define VSHOT_IINSPECTABLE_SLOTS(T) \
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(T *This, REFIID riid, void **ppvObject); \
    ULONG (STDMETHODCALLTYPE *AddRef)(T *This); \
    ULONG (STDMETHODCALLTYPE *Release)(T *This); \
    HRESULT (STDMETHODCALLTYPE *GetIids)(T *This, ULONG *iidCount, IID **iids); \
    HRESULT (STDMETHODCALLTYPE *GetRuntimeClassName)(T *This, HSTRING *className); \
    HRESULT (STDMETHODCALLTYPE *GetTrustLevel)(T *This, TrustLevel *trustLevel);

/* Windows.Media.Ocr.IOcrEngineStatics (fábrica estática de OcrEngine) */
typedef struct __x_ABI_CWindows_CMedia_COcr_CIOcrEngineStaticsVtbl {
    VSHOT_IINSPECTABLE_SLOTS(__x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics)
    HRESULT (STDMETHODCALLTYPE *get_MaxImageDimension)(__x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics *This, UINT32 *value);                       /* slot 6 */
    HRESULT (STDMETHODCALLTYPE *get_AvailableRecognizerLanguages)(__x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics *This, __FIVectorView_1_Windows__CGlobalization__CLanguage **value); /* 7 */
    HRESULT (STDMETHODCALLTYPE *IsLanguageSupported)(__x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics *This, __x_ABI_CWindows_CGlobalization_CILanguage *language, boolean *result); /* 8 */
    HRESULT (STDMETHODCALLTYPE *TryCreateFromLanguage)(__x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics *This, __x_ABI_CWindows_CGlobalization_CILanguage *language, __x_ABI_CWindows_CMedia_COcr_CIOcrEngine **result); /* 9 */
    HRESULT (STDMETHODCALLTYPE *TryCreateFromUserProfileLanguages)(__x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics *This, __x_ABI_CWindows_CMedia_COcr_CIOcrEngine **result); /* 10 */
} __x_ABI_CWindows_CMedia_COcr_CIOcrEngineStaticsVtbl;
struct __x_ABI_CWindows_CMedia_COcr_CIOcrEngineStatics { const __x_ABI_CWindows_CMedia_COcr_CIOcrEngineStaticsVtbl *lpVtbl; };

/* Windows.Media.Ocr.IOcrEngine */
typedef struct __x_ABI_CWindows_CMedia_COcr_CIOcrEngineVtbl {
    VSHOT_IINSPECTABLE_SLOTS(__x_ABI_CWindows_CMedia_COcr_CIOcrEngine)
    HRESULT (STDMETHODCALLTYPE *RecognizeAsync)(__x_ABI_CWindows_CMedia_COcr_CIOcrEngine *This, __x_ABI_CWindows_CGraphics_CImaging_CISoftwareBitmap *bitmap, __FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult **result); /* 6 */
    HRESULT (STDMETHODCALLTYPE *get_RecognizerLanguage)(__x_ABI_CWindows_CMedia_COcr_CIOcrEngine *This, __x_ABI_CWindows_CGlobalization_CILanguage **value); /* 7 */
} __x_ABI_CWindows_CMedia_COcr_CIOcrEngineVtbl;
struct __x_ABI_CWindows_CMedia_COcr_CIOcrEngine { const __x_ABI_CWindows_CMedia_COcr_CIOcrEngineVtbl *lpVtbl; };

/* Windows.Media.Ocr.IOcrResult */
typedef struct __x_ABI_CWindows_CMedia_COcr_CIOcrResultVtbl {
    VSHOT_IINSPECTABLE_SLOTS(__x_ABI_CWindows_CMedia_COcr_CIOcrResult)
    HRESULT (STDMETHODCALLTYPE *get_Lines)(__x_ABI_CWindows_CMedia_COcr_CIOcrResult *This, __FIVectorView_1_Windows__CMedia__COcr__COcrLine **value); /* 6 */
    HRESULT (STDMETHODCALLTYPE *get_TextAngle)(__x_ABI_CWindows_CMedia_COcr_CIOcrResult *This, IUnknown **value); /* 7: IReference<double>*, pode ser NULL */
    HRESULT (STDMETHODCALLTYPE *get_Text)(__x_ABI_CWindows_CMedia_COcr_CIOcrResult *This, HSTRING *value); /* 8 */
} __x_ABI_CWindows_CMedia_COcr_CIOcrResultVtbl;
struct __x_ABI_CWindows_CMedia_COcr_CIOcrResult { const __x_ABI_CWindows_CMedia_COcr_CIOcrResultVtbl *lpVtbl; };

/* Windows.Media.Ocr.IOcrLine */
typedef struct __x_ABI_CWindows_CMedia_COcr_CIOcrLineVtbl {
    VSHOT_IINSPECTABLE_SLOTS(__x_ABI_CWindows_CMedia_COcr_CIOcrLine)
    HRESULT (STDMETHODCALLTYPE *get_Words)(__x_ABI_CWindows_CMedia_COcr_CIOcrLine *This, IUnknown **value); /* 6: IVectorView<OcrWord>* */
    HRESULT (STDMETHODCALLTYPE *get_Text)(__x_ABI_CWindows_CMedia_COcr_CIOcrLine *This, HSTRING *value); /* 7 */
} __x_ABI_CWindows_CMedia_COcr_CIOcrLineVtbl;
struct __x_ABI_CWindows_CMedia_COcr_CIOcrLine { const __x_ABI_CWindows_CMedia_COcr_CIOcrLineVtbl *lpVtbl; };

/* Windows.Foundation.IAsyncOperation<OcrResult> (herda IInspectable; IAsyncInfo via QueryInterface) */
typedef struct __FIAsyncOperation_1_Windows__CMedia__COcr__COcrResultVtbl {
    VSHOT_IINSPECTABLE_SLOTS(__FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult)
    HRESULT (STDMETHODCALLTYPE *put_Completed)(__FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult *This, IUnknown *handler); /* 6: AsyncOperationCompletedHandler<OcrResult>* */
    HRESULT (STDMETHODCALLTYPE *get_Completed)(__FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult *This, IUnknown **handler); /* 7 */
    HRESULT (STDMETHODCALLTYPE *GetResults)(__FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult *This, __x_ABI_CWindows_CMedia_COcr_CIOcrResult **results); /* 8 */
} __FIAsyncOperation_1_Windows__CMedia__COcr__COcrResultVtbl;
struct __FIAsyncOperation_1_Windows__CMedia__COcr__COcrResult { const __FIAsyncOperation_1_Windows__CMedia__COcr__COcrResultVtbl *lpVtbl; };

/* Windows.Foundation.Collections.IVectorView<OcrLine> */
typedef struct __FIVectorView_1_Windows__CMedia__COcr__COcrLineVtbl {
    VSHOT_IINSPECTABLE_SLOTS(__FIVectorView_1_Windows__CMedia__COcr__COcrLine)
    HRESULT (STDMETHODCALLTYPE *GetAt)(__FIVectorView_1_Windows__CMedia__COcr__COcrLine *This, UINT32 index, __x_ABI_CWindows_CMedia_COcr_CIOcrLine **item); /* 6 */
    HRESULT (STDMETHODCALLTYPE *get_Size)(__FIVectorView_1_Windows__CMedia__COcr__COcrLine *This, UINT32 *size); /* 7 */
    HRESULT (STDMETHODCALLTYPE *IndexOf)(__FIVectorView_1_Windows__CMedia__COcr__COcrLine *This, __x_ABI_CWindows_CMedia_COcr_CIOcrLine *value, UINT32 *index, boolean *found); /* 8 */
    HRESULT (STDMETHODCALLTYPE *GetMany)(__FIVectorView_1_Windows__CMedia__COcr__COcrLine *This, UINT32 start_index, UINT32 items_size, __x_ABI_CWindows_CMedia_COcr_CIOcrLine **items, UINT32 *count); /* 9 */
} __FIVectorView_1_Windows__CMedia__COcr__COcrLineVtbl;
struct __FIVectorView_1_Windows__CMedia__COcr__COcrLine { const __FIVectorView_1_Windows__CMedia__COcr__COcrLineVtbl *lpVtbl; };

#undef VSHOT_IINSPECTABLE_SLOTS

#endif /* __windows_media_ocr_h__ */

/* IIDs das interfaces que já têm header no MinGW, declarados localmente para não depender de INITGUID/libuuid. */
static const IID IID_VShot_ISoftwareBitmapStatics = {0xdf0385db, 0x672f, 0x4a9d, {0x80,0x6e, 0xc2,0x44,0x2f,0x34,0x3e,0x86}};
static const IID IID_VShot_ICryptographicBufferStatics = {0x320b7e22, 0x3cb0, 0x4cdf, {0x86,0x63, 0x1d,0x28,0x91,0x00,0x65,0xeb}};
static const IID IID_VShot_ILanguageFactory = {0x9b0252ac, 0x0c27, 0x44f8, {0xb7,0x92, 0x97,0x93,0xfb,0x66,0xc6,0x3e}};
static const IID IID_VShot_IAsyncInfo = {0x00000036, 0x0000, 0x0000, {0xc0,0x00, 0x00,0x00,0x00,0x00,0x00,0x46}};

#endif /* VSHOT_OCR_WINRT_H */
