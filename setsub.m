function C = setsub(A,B)

    % C = setsub(A,B);
    % set subtraction for anything that works with ismember()
    %
    % C = A - B;
    
    C = A;
    C( ismember(C,B) ) = [];
    
end
