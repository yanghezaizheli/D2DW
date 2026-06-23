#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
詳細地図PDF → PNG 変換ツール
変換したPNGを Supabase Storage（公開バケット）等にアップし、
そのURLを blocks.detail_map_url に設定すると、アプリの詳細地図が実地図になります。

準備: pip install pymupdf
使い方:
  python pdf_to_png.py "01長住2(長住2-3)詳細.pdf"            # 同名.pngを出力(150dpi)
  python pdf_to_png.py 入力.pdf 出力.png 200                 # DPI指定
"""
import sys

def main():
    try:
        import fitz  # PyMuPDF
    except ImportError:
        print("PyMuPDF が必要です: pip install pymupdf"); return
    if len(sys.argv) < 2:
        print('usage: python pdf_to_png.py input.pdf [output.png] [dpi]'); return
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else src.rsplit('.', 1)[0] + '.png'
    dpi = int(sys.argv[3]) if len(sys.argv) > 3 else 150
    doc = fitz.open(src)
    pix = doc[0].get_pixmap(dpi=dpi)   # 1ページ目を画像化
    pix.save(out)
    print(f'saved {out}  ({pix.width}x{pix.height}px @ {dpi}dpi)')
    print('→ この画像を Supabase Storage(公開) にアップし、URLを下記で設定:')
    print("   update blocks set detail_map_url='<公開URL>' where name='長住2-3';")

if __name__ == '__main__':
    main()
