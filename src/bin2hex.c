/**
 *  Copyright (C) 2026, Kees Krijnen.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  This program is distributed WITHOUT ANY WARRANTY; without even the implied
 *  warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <https://www.gnu.org/licenses/> for a copy.
 *
 *  License: GPL, v3, as defined and found on www.gnu.org,
 *           https://www.gnu.org/licenses/gpl-3.0.html
 *
 *  Description: Binary to HEX file conversion as input for verilog $readmemh.
 *               Default little endian binary and 32-bit numbers (4 bytes).
 */

#include <stdio.h>

int main( int argc, char** argv )
{
    int error = 0;
    int size = 4; // Size in number of bytes
    int littleEndian = 1; // Default little endian binary format

    if ( argc > 1 ) {
        char* pArgv = argv[1];

        if ( '-' == pArgv[0] ) {
            if ( 0 == pArgv[1] ) {
                error = 1;
            } else {
                if ( 'B' == pArgv[1] ) {
                    littleEndian = 0;
                } else if ( 'L' != pArgv[1] ) error = 1;


                if (( pArgv[2] >= '1' ) && ( pArgv[2] <= '9' )) {
                    size = pArgv[2] - '0';

                    if (( pArgv[3] >= '1' ) && ( pArgv[3] <= '9' ) && ( 0 == pArgv[4] )) {
                        size = ( 10 * size ) + pArgv[3] - '0'; 
                    } else if ( pArgv[3] != 0 ) error = 1;
                } else if ( pArgv[2] != 0 ) error = 1;


                if ( argc != 3 ) error = 1;
            }
        } else if ( argc > 2 ) error = 1;
    } else error = 1;

    if ( error ) {
        printf( "usage:    bin2hex [option] bin_file\n" );
        printf( "options:  default -L4\n" );
        printf( "  -B[x] Big endian, optional x = number of bytes (1-99)\n" );
        printf( "  -L[x] Little endian, optional x = number of bytes (1-99)\n" );
    } else {

        const int maxFileNameLength = 1000;
        char hexFileName[maxFileNameLength+1]; // + '/0' string delimeter!
        int fileNameIndex = 0;
        int dotIndex = -1;
        char* pFile = ( 2 == argc ) ? argv[1] : argv[2];

        while (( pFile[fileNameIndex] != 0 ) && ( fileNameIndex < maxFileNameLength )) {
            hexFileName[fileNameIndex] = pFile[fileNameIndex];

            if ( '.' == hexFileName[fileNameIndex] ) dotIndex = fileNameIndex;

            fileNameIndex = fileNameIndex + 1;
        }

        if ( dotIndex < 0 ) { // Check for extension ".hex" size
            if ( fileNameIndex > ( maxFileNameLength - 4 )) {
                error = 1;

            } else {
                hexFileName[fileNameIndex] = '.';
                dotIndex = fileNameIndex;
            }
        }
        else if ( dotIndex > ( maxFileNameLength - 4 )) error = 1;

        if ( error ) {
            printf( "Could not process input file name %s\n", pFile );
        } else {
            FILE* binFile = NULL;
            FILE* hexFile = NULL;

            binFile = fopen( pFile, "rb" );

            if ( binFile ) {
                hexFileName[++dotIndex] = 'h';
                hexFileName[++dotIndex] = 'e';
                hexFileName[++dotIndex] = 'x';
                hexFileName[++dotIndex] = 0; // String delimeter

                hexFile = fopen( hexFileName, "wb" );

                if ( NULL == hexFile ) printf( "Could not create hex file %s\n", hexFileName );
            } else printf( "Could not open input file %s\n", pFile );

            if ( binFile && hexFile ) {
                const int maxBytesToRead = 99; // -B99 or -L99
                unsigned char inputBytes[maxBytesToRead];
                int byteIndex = littleEndian ? ( size - 1 ) : 0;
                int writeHex;
                int nbItems = -1; // Non-zero value
                const char space = ' ';
                const char lineFeed = '\n';
                char hexValue[2];
                char hexNibble;
                int column = 0;
                int i;

                while ( 0 != nbItems ) {
                    nbItems = fread( &inputBytes[byteIndex], 1, 1, binFile ); // Read single byte!

                    if ( nbItems ) {
                        writeHex = 0;
                        
                        if ( littleEndian ) {
                            byteIndex--;

                            if ( -1 == byteIndex ) {
                                byteIndex = size - 1;
                                writeHex = 1;
                            }
                        } else {    
                            byteIndex++;

                            if ( size == byteIndex ) {
                                byteIndex = 0;
                                writeHex = 1;
                            }
                        }    
                    } else {
                        writeHex = 1;

                        if ( littleEndian ) {
                            for ( i = 0; i < ( byteIndex + 1 ); i++ ) inputBytes[i] = 0;
                        } else {    
                            for ( i = byteIndex; i < size; i++ ) inputBytes[i] = 0;
                        }
                    }

                    if ( writeHex ) {

                        for ( i = 0; i < size; i++ ) {
                            hexNibble = inputBytes[i] >> 4; // hexNibble: 10 + '7' = 'A' 
                            hexValue[0] = ( hexNibble > 9 ) ? hexNibble + '7' : hexNibble + '0';
                            hexNibble = inputBytes[i] & 0x0F; // hexNibble: 15 + '7' = 'F' 
                            hexValue[1] = ( hexNibble > 9 ) ? hexNibble + '7' : hexNibble + '0';
                            fwrite( hexValue, 2, 1, hexFile );
                            column = column + 2;
                        }

                        column++;

                        if (( column > 70 ) || ( 0 == nbItems )) {
                            fwrite( &lineFeed, 1, 1, hexFile );
                            column = 0;
                        } else {
                            fwrite( &space, 1, 1, hexFile );
                        }
                    }
                }
            }

            (void)fclose(binFile);
            (void)fclose(hexFile);
        }
    }

    return 0;
}
