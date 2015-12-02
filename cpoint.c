# include <stdlib.h>

typedef struct {
  int x;
  int y;
} Cpoint;

Cpoint *get_cpoint(int a, int b) {
  Cpoint *cpoint;
  cpoint = (Cpoint*) malloc(sizeof(Cpoint));
  cpoint->x = a;
  cpoint->y = b;
  return cpoint;
};

Cpoint *bad_cpoint(int a, int b) {
  Cpoint cpoint;
  cpoint.x = a;
  cpoint.y = b;
  return &cpoint;
}

void mutate_cpoint(int a, int b, Cpoint *cpoint) {
  cpoint->x = a;
  cpoint->y = b;
}
