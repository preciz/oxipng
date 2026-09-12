#include <png.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    FILE *f = fopen(argv[1], "rb");
    if (!f) return 2;
    png_structp p = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    png_infop info = png_create_info_struct(p);
    if (setjmp(png_jmpbuf(p))) { png_destroy_read_struct(&p, &info, NULL); fclose(f); return 1; }
    png_init_io(p, f);
    png_read_info(p, info);
    int color = png_get_color_type(p, info);
    if (color == PNG_COLOR_TYPE_PALETTE) png_set_palette_to_rgb(p);
    if (color == PNG_COLOR_TYPE_GRAY && png_get_bit_depth(p,info) < 8) png_set_expand_gray_1_2_4_to_8(p);
    int trns = png_get_valid(p, info, PNG_INFO_tRNS);
    if (trns) png_set_tRNS_to_alpha(p);
    png_set_expand_16(p);
    if (color == PNG_COLOR_TYPE_GRAY || color == PNG_COLOR_TYPE_GRAY_ALPHA) png_set_gray_to_rgb(p);
    if (!(color & PNG_COLOR_MASK_ALPHA) && !trns) png_set_add_alpha(p, 65535, PNG_FILLER_AFTER);
    png_set_interlace_handling(p);
    png_read_update_info(p,info);
    size_t stride = png_get_rowbytes(p, info), height = png_get_image_height(p, info);
    unsigned char *buffer = malloc(stride * height);
    png_bytep *rows = malloc(sizeof(png_bytep) * height);
    if (!buffer || !rows) return 2;
    for (size_t i=0;i<height;i++) rows[i]=buffer+i*stride;
    png_read_image(p,rows);
    png_read_end(p, info);
    if (argc == 3) {
        FILE *out=fopen(argv[2], "wb");
        if (!out) return 2;
        fwrite(buffer,stride,height,out); fclose(out);
    }
    free(rows); free(buffer); png_destroy_read_struct(&p, &info, NULL); fclose(f);
    return 0;
}
