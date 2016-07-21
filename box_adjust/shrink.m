function move = shrink(x,y,w,h,r,r2,fli,small_w,small_h)
    move = [x+(w/2)-small_w/2,y+(h/2)-small_h/2,small_w,small_h];