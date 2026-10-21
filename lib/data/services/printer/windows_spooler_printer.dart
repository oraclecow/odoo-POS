import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

final class DocInfo1W extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDataType;
}

typedef OpenPrinterWNative = Int32 Function(
  Pointer<Utf16> pPrinterName,
  Pointer<IntPtr> phPrinter,
  Pointer<Void> pDefault,
);
typedef OpenPrinterWDart = int Function(
  Pointer<Utf16> pPrinterName,
  Pointer<IntPtr> phPrinter,
  Pointer<Void> pDefault,
);

typedef StartDocPrinterWNative = Uint32 Function(
  IntPtr hPrinter,
  Uint32 level,
  Pointer<DocInfo1W> pDocInfo,
);
typedef StartDocPrinterWDart = int Function(
  int hPrinter,
  int level,
  Pointer<DocInfo1W> pDocInfo,
);

typedef StartPagePrinterNative = Int32 Function(IntPtr hPrinter);
typedef StartPagePrinterDart = int Function(int hPrinter);

typedef WritePrinterNative = Int32 Function(
  IntPtr hPrinter,
  Pointer<Uint8> pBuf,
  Uint32 cbBuf,
  Pointer<Uint32> pcWritten,
);
typedef WritePrinterDart = int Function(
  int hPrinter,
  Pointer<Uint8> pBuf,
  int cbBuf,
  Pointer<Uint32> pcWritten,
);

typedef EndPagePrinterNative = Int32 Function(IntPtr hPrinter);
typedef EndPagePrinterDart = int Function(int hPrinter);

typedef EndDocPrinterNative = Int32 Function(IntPtr hPrinter);
typedef EndDocPrinterDart = int Function(int hPrinter);

typedef ClosePrinterNative = Int32 Function(IntPtr hPrinter);
typedef ClosePrinterDart = int Function(int hPrinter);

typedef GetDefaultPrinterWNative = Int32 Function(
  Pointer<Utf16> pszBuffer,
  Pointer<Uint32> pcchBuffer,
);
typedef GetDefaultPrinterWDart = int Function(
  Pointer<Utf16> pszBuffer,
  Pointer<Uint32> pcchBuffer,
);

typedef GetLastErrorNative = Uint32 Function();
typedef GetLastErrorDart = int Function();

class WindowsSpoolerPrinter {
  static String? getDefaultPrinter() {
    if (!Platform.isWindows) return null;
    try {
      final winspool = DynamicLibrary.open('winspool.drv');
      final getDefaultPrinterFn =
          winspool.lookupFunction<GetDefaultPrinterWNative, GetDefaultPrinterWDart>('GetDefaultPrinterW');

      final bufferSize = calloc<Uint32>();
      getDefaultPrinterFn(nullptr, bufferSize);
      if (bufferSize.value == 0) {
        calloc.free(bufferSize);
        return null;
      }

      final buffer = calloc<Uint16>(bufferSize.value);
      final res = getDefaultPrinterFn(buffer.cast<Utf16>(), bufferSize);
      String? name;
      if (res != 0) {
        name = buffer.cast<Utf16>().toDartString();
      }
      calloc.free(buffer);
      calloc.free(bufferSize);
      return name;
    } catch (e) {
      debugPrint('[WindowsSpooler] getDefaultPrinter error: $e');
      return null;
    }
  }

  /// Sends raw ESC/POS bytes directly to Windows Print Spooler (RAW datatype).
  /// This completely bypasses any HTTP/Python proxy and prints directly to the USB printer.
  static Future<Map<String, dynamic>> printRawBytes(
    List<int> bytes, {
    String? printerName,
    String docName = 'POS Receipt',
  }) async {
    if (!Platform.isWindows) {
      return {'success': false, 'message': 'Hanya didukung di Windows'};
    }

    if (bytes.isEmpty) {
      return {'success': false, 'message': 'Data cetak kosong'};
    }

    DynamicLibrary winspool;
    DynamicLibrary kernel32;
    try {
      winspool = DynamicLibrary.open('winspool.drv');
      kernel32 = DynamicLibrary.open('kernel32.dll');
    } catch (e) {
      return {'success': false, 'message': 'Gagal memuat winspool.drv: $e'};
    }

    final openPrinter = winspool.lookupFunction<OpenPrinterWNative, OpenPrinterWDart>('OpenPrinterW');
    final startDocPrinter = winspool.lookupFunction<StartDocPrinterWNative, StartDocPrinterWDart>('StartDocPrinterW');
    final startPagePrinter = winspool.lookupFunction<StartPagePrinterNative, StartPagePrinterDart>('StartPagePrinter');
    final writePrinter = winspool.lookupFunction<WritePrinterNative, WritePrinterDart>('WritePrinter');
    final endPagePrinter = winspool.lookupFunction<EndPagePrinterNative, EndPagePrinterDart>('EndPagePrinter');
    final endDocPrinter = winspool.lookupFunction<EndDocPrinterNative, EndDocPrinterDart>('EndDocPrinter');
    final closePrinter = winspool.lookupFunction<ClosePrinterNative, ClosePrinterDart>('ClosePrinter');
    final getLastError = kernel32.lookupFunction<GetLastErrorNative, GetLastErrorDart>('GetLastError');

    String target = printerName?.trim() ?? '';
    if (target.isEmpty) {
      target = getDefaultPrinter() ?? '58mm Series Printer';
    }

    var pPrinterName = target.toNativeUtf16();
    final phPrinter = calloc<IntPtr>();

    try {
      var openRes = openPrinter(pPrinterName, phPrinter, nullptr);

      // If opening failed on specified target, attempt fallback to Windows default printer
      if (openRes == 0) {
        final defPrinter = getDefaultPrinter();
        if (defPrinter != null && defPrinter.isNotEmpty && defPrinter != target) {
          debugPrint('[WindowsSpooler] Target "$target" failed, trying Windows default printer "$defPrinter"...');
          calloc.free(pPrinterName);
          target = defPrinter;
          pPrinterName = target.toNativeUtf16();
          openRes = openPrinter(pPrinterName, phPrinter, nullptr);
        }
      }

      if (openRes == 0) {
        final err = getLastError();
        return {
          'success': false,
          'message': 'Gagal membuka printer Windows "$target" (Error $err). Pastikan printer USB menyala dan terpasang.',
        };
      }

      final hPrinter = phPrinter.value;
      final docInfo = calloc<DocInfo1W>();
      docInfo.ref.pDocName = docName.toNativeUtf16();
      docInfo.ref.pOutputFile = nullptr;
      docInfo.ref.pDataType = 'RAW'.toNativeUtf16();

      try {
        final docId = startDocPrinter(hPrinter, 1, docInfo);
        if (docId == 0) {
          final err = getLastError();
          return {'success': false, 'message': 'Gagal memulai dokumen cetak RAW di $target (Error $err)'};
        }

        try {
          // Some RAW POS drivers fail StartPagePrinter, but WritePrinter still succeeds.
          final pageRes = startPagePrinter(hPrinter);
          final pageStarted = pageRes != 0;

          final pBuf = calloc<Uint8>(bytes.length);
          final byteList = pBuf.asTypedList(bytes.length);
          byteList.setAll(0, bytes);
          final pcWritten = calloc<Uint32>();

          try {
            final writeRes = writePrinter(hPrinter, pBuf, bytes.length, pcWritten);
            if (writeRes == 0) {
              final err = getLastError();
              return {'success': false, 'message': 'Gagal menulis data ke spooler printer $target (Error $err)'};
            }
          } finally {
            calloc.free(pBuf);
            calloc.free(pcWritten);
            if (pageStarted) {
              endPagePrinter(hPrinter);
            }
          }
        } finally {
          endDocPrinter(hPrinter);
        }
      } finally {
        calloc.free(docInfo.ref.pDocName);
        calloc.free(docInfo.ref.pDataType);
        calloc.free(docInfo);
        closePrinter(hPrinter);
      }

      debugPrint('[WindowsSpooler] Successfully sent ${bytes.length} bytes to $target via winspool.drv RAW');
      return {
        'success': true,
        'simulated': false,
        'message': 'Berhasil dicetak langsung ke $target (${bytes.length} bytes)',
      };
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
    }
  }
}
