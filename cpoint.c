# include <stdlib.h>

typedef struct {
  int x;
  int y;
} Cpoint;

Cpoint *get_cpoint(int a, int b) {
  Cpoint *cpoint;
  cpoint = (Cpoint*) malloc(sizeof(Cpoint));
  cpoint->x = 1;
  cpoint->y = 2;
  return cpoint;
};

Cpoint *bad_cpoint(int a, int b) {
  Cpoint cpoint;
  cpoint.x = 1;
  cpoint.y = 2;
  return &cpoint;
}
