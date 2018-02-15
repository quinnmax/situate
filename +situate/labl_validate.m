function [fnames_pass, ...
          fnames_fail, ...
          exceptions, ...
          failed_inds] = labl_validate( fnames_in, varargin )

    % [fnames_lb_train_pass, fnames_lb_train_fail, exceptions, failed_inds] = labl_validate( fnames_labl, [situation_struct] );
    %
    %   checks to make sure all boxes are in bounds
    %   if there's a situation struct, also makes sure that all situation objects are represented
    
    was_situation_struct = false;
    if isempty(varargin) || isempty(varargin{1})
        situation_struct = [];
    else
        situation_struct = varargin{1};
        was_situation_struct = true;
    end
    
    label_data = situate.labl_load( fnames_in, situation_struct );
    fnames_in_all = {label_data.fname_lb};
    
    failed_inds = false(1,length(fnames_in_all));
    exceptions = cell(1,length(fnames_in_all));
    for fi = 1:length(fnames_in_all)
        
        try
            assert( all( label_data(fi).boxes_r0rfc0cf(:,1) >= 1 ), 'row_initial too low' );
            assert( all( label_data(fi).boxes_r0rfc0cf(:,2) <= label_data(fi).im_h ), 'row_final too high' );
            assert( all( label_data(fi).boxes_r0rfc0cf(:,3) >= 1 ), 'column_initial too low' );
            assert( all( label_data(fi).boxes_r0rfc0cf(:,4) <= label_data(fi).im_w ), 'column_final too high' );
            
            if was_situation_struct
                assert( all( ismember( situation_struct.situation_objects, label_data(fi).labels_adjusted ) ), 'not all situation objects present' );
            end
            
        catch blerg
            exceptions{fi}   = blerg;
            failed_inds(fi)  = true;
        end
        
    end
    
    
    fnames_pass = fnames_in_all(~failed_inds);
    fnames_fail = fnames_in_all( failed_inds);
    exceptions = exceptions( failed_inds);
    
    if ~isempty(fnames_fail)
        warning('some image labels failed validation');
        display(fnames_fail);
    end
    
end

