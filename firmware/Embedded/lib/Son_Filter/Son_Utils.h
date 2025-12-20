#ifndef SON_UTILS_H_
#define SON_UTILS_H_


#define UTILS_LOW_PASS_FILTER(value, sample, constant)	(value -= (constant) * ((value) - (sample)))
#define UTILS_LOW_PASS_FILTER_2(value, sample, lconstant, hconstant)\
  if (sample < value) {\
    UTILS_LOW_PASS_FILTER(value, sample, lconstant);\
  }\
  else {\
    UTILS_LOW_PASS_FILTER(value, sample, hconstant);\
  }

#define SIMPLE_KALMAN_FILTER(value, sample, gain) (value += gain * (sample - value))

static float haftToFloat(uint16_t num) {
  uint32_t num_32bit =  ((num&0x8000)<<16) | (((num&0x7c00)+0x1C000)<<13) | ((num&0x03FF)<<13);
  return *((float*)&num_32bit);
}

static uint16_t floatToHaft(float num) {
  uint32_t num_32bit = *((uint32_t*)&num);
  return ((num_32bit>>16)&0x8000)|((((num_32bit&0x7f800000)-0x38000000)>>13)&0x7c00)|((num_32bit>>13)&0x03ff);
}

#define mapFloat(x, in_min, in_max, out_min, out_max) \
  ((x - (in_min)) * ((out_max) - (out_min)) / ((in_max) - (in_min)) + (out_min))


#endif
