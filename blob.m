function out = blob( dims, p, n )

% out = blob( dims, p, n );
%
% dims are the dimensions of the output image, such as [100 200 3]
% p is the center point of the (blackman filter) blob [row column]
% n is the size of the blackman blob

    if length(dims)<2
        dims(2) = dims(1);
    end
    if length(dims) < 3
        dims(3) = 1;
    end
    
    y = blackman(n)*blackman(n)';
    y = repmat(y,[1 1 dims(3)]);
    
    % xp = padarray(x,[n n]);
    xp = zeros( x(1)+2*n, x(2)+2*n, x(3) );
    
    r0 = round( p(1) + n - n/2 );
    rf = r0 + n - 1;
    c0 = round( p(2) + n - n/2 );
    cf = c0 + n - 1;
    xp(r0:rf,c0:cf,:) = y;
    
    out = xp(n+1:end-n,n+1:end-n);
    
end