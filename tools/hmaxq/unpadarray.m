function y = unpadarray(x,padsize)

% y = unpadarray(x,padsize);
%
%   r0 = padsize(1) + 1;
%   rf = size(x,1)  - padsize(1);
%
%   c0 = padsize(2) + 1;
%   cf = size(x,2)  - padsize(2);
%
%   y = x( r0:rf, c0:cf, : );
%
%   unpadarray( padarray( x, padsize ), padsize ) == x

    r0 = padsize(1) + 1;
    rf = size(x,1)  - padsize(1);
    c0 = padsize(2) + 1;
    cf = size(x,2)  - padsize(2);
   
    y = x( r0:rf, c0:cf, : );

end