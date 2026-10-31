/* A API plana do GDI+, declarada à mão.
 *
 * O gdiplus.h que acompanha o compilador é C++: ele declara classes, e o gdiplusflat.h
 * que traz estas funções está dentro da mesma guarda de __cplusplus. Como a DLL exporta
 * estes símbolos com nome plano, declará-los aqui é o caminho mais curto para chegar até
 * eles a partir do V, que gera C. */
#ifndef PRINTSCREEN_GDIPFLAT_H
#define PRINTSCREEN_GDIPFLAT_H

#include <windows.h>

typedef struct GdiplusStartupInputC {
	UINT32 GdiplusVersion;
	void *DebugEventCallback;
	BOOL SuppressBackgroundThread;
	BOOL SuppressExternalCodecs;
} GdiplusStartupInputC;

int __stdcall GdiplusStartup(ULONG_PTR *token, const GdiplusStartupInputC *input, void *output);
void __stdcall GdiplusShutdown(ULONG_PTR token);
int __stdcall GdipCreateFromHDC(HDC hdc, void **graphics);
int __stdcall GdipDeleteGraphics(void *graphics);
int __stdcall GdipSetSmoothingMode(void *graphics, int mode);
int __stdcall GdipCreatePen1(UINT32 argb, float width, int unit, void **pen);
int __stdcall GdipDeletePen(void *pen);
int __stdcall GdipDrawRectangle(void *graphics, void *pen, float x, float y, float width, float height);
int __stdcall GdipCreateSolidFill(UINT32 argb, void **brush);
int __stdcall GdipDeleteBrush(void *brush);
int __stdcall GdipFillEllipse(void *graphics, void *brush, float x, float y, float width, float height);
int __stdcall GdipDrawEllipse(void *graphics, void *pen, float x, float y, float width, float height);
int __stdcall GdipDrawLine(void *graphics, void *pen, float x1, float y1, float x2, float y2);
int __stdcall GdipSetPenDashStyle(void *pen, int style);
int __stdcall GdipSetPenStartCap(void *pen, int cap);
int __stdcall GdipSetPenEndCap(void *pen, int cap);
int __stdcall GdipSetPenDashCap197819(void *pen, int dashCap);
int __stdcall GdipSetClipRectI(void *graphics, int x, int y, int width, int height, int mode);

typedef struct GdipPointI {
	int X;
	int Y;
} GdipPointI;

typedef struct GdipPointF { float X; float Y; } GdipPointF;
int __stdcall GdipFillPolygon(void *graphics, void *brush, const GdipPointF *points, int count, int mode);
int __stdcall GdipDrawCurveI(void *graphics, void *pen, const GdipPointI *points, int count);
int __stdcall GdipFillRectangleI(void *graphics, void *brush, int x, int y, int width, int height);
int __stdcall GdipCreatePath(int mode, void **path);
int __stdcall GdipDeletePath(void *path);
int __stdcall GdipAddPathArcI(void *path, int x, int y, int width, int height, float start, float sweep);
int __stdcall GdipClosePathFigure(void *path);
int __stdcall GdipDrawPath(void *graphics, void *pen, void *path);
int __stdcall GdipFillPath(void *graphics, void *brush, void *path);
int __stdcall GdipStartPathFigure(void *path);
int __stdcall GdipAddPathLine(void *path, float x1, float y1, float x2, float y2);
int __stdcall GdipAddPathBezier(void *path, float x1, float y1, float x2, float y2, float x3, float y3, float x4, float y4);
int __stdcall GdipAddPathEllipse(void *path, float x, float y, float width, float height);
int __stdcall GdipAddPathArc(void *path, float x, float y, float width, float height, float start, float sweep);
int __stdcall GdipSetPenLineJoin(void *pen, int join);
int __stdcall GdipTranslateWorldTransform(void *graphics, float dx, float dy, int order);
int __stdcall GdipResetWorldTransform(void *graphics);

#endif
