
function [crops,crop_desc,crops_background,crops_background_desc,failed_files] = dir2crops( directory_in, varargin )
% dir2crops( directory_in, [directory_out], [include_n_paired_background_crops] );
%
%   directory_in should contain all image files and label files
%
%   if directory_out is empty, then no files will be saved
%
%   include_n_paired_background_crops is per object in the label file
%
%   output format is 'image_name.label.num.ext' for objects in the label files
%   output format is 'image_name.label.background.num.ext' for paired background crops

    switch length( varargin )
        
        case 0
            save_crops_to_file = false;
            num_background_crops = 0;
        
        case 1
            if ischar(varagin{1})
                directory_out = varargin{1};
                num_background_crops = 0;
                save_crops_to_file = true;
                if ~exist( directory_out,'dir')
                    mkdir( directory_out );
                end
            elseif isnumeric( varargin{1} )
                num_background_crops = varargin{1};
                save_crops_to_file = false;
            end
            
        case 2
            directory_out = varargin{1};
            num_background_crops = varargin{2};
            if ischar(directory_out)
                save_crops_to_file = true;
                if ~exist( directory_out,'dir')
                    mkdir( directory_out );
                end
            end
            
        otherwise
            error('too many input args');
    end
    
    label_file_dir_data = dir( fullfile(directory_in,'*.labl') );
    label_file_fnames = cellfun( @(x) fullfile(directory_in,x), {label_file_dir_data.name}, 'UniformOutput', false ); 
    label_data = situate.labl_load( label_file_fnames );

    total_boxes = sum( cellfun( @length, {label_data(:).labels_raw} ) );
    
    failed_files = {};
    crops = cell(1,total_boxes);
    crop_desc = cell(1,total_boxes);
    crops_background_desc = {};

    crops_background = {};
    
    ki = 1;
    for imi = 1:length(label_data)

        try
        
            cur_im_fname = [label_data(imi).fname_lb(1:end-4) 'jpg'];
            cur_im = imread( cur_im_fname );

            [~,fname_part,~] = fileparts(cur_im_fname);

            for bi  = 1:length(label_data(imi).labels_raw)

                cur_label = label_data(imi).labels_raw{bi};
                r0 = label_data(imi).boxes_r0rfc0cf(bi,1);
                rf = label_data(imi).boxes_r0rfc0cf(bi,2);
                c0 = label_data(imi).boxes_r0rfc0cf(bi,3);
                cf = label_data(imi).boxes_r0rfc0cf(bi,4);
                cur_crop = cur_im(r0:rf,c0:cf,:);
                
                cur_crop_desc = sprintf('%s.%s.%d',fname_part,cur_label,bi);
                
                if save_crops_to_file
                    fname_out = [cur_crop_desc '.jpg'];
                    fname_out = strrep( fname_out, '/', 'a' );
                    fname_out = strrep( fname_out, '\', 'b' );
                    fname_out_w_dir = fullfile( directory_out, fname_out );
                    imwrite(cur_crop,fname_out_w_dir,'jpg');
                else
                    crops{ki} = cur_crop;
                    crop_desc{ki} = cur_crop_desc;
                    ki = ki + 1;
                end
                
                if num_background_crops > 0
                    background_crops = generate_background_crops( cur_im, [r0 rf c0 cf], num_background_crops);
                    crops_background(end+1:end+length(background_crops)) = background_crops;
                    for bj = 1:length(background_crops)
                        cur_crop_desc = sprintf('%s.%s.background.%d.%d',fname_part,cur_label,bi,bj);
                        crops_background_desc{end+1} = cur_crop_desc;
                        if save_crops_to_file
                            fname_out = [cur_crop_desc '.jpg'];
                            fname_out = strrep( fname_out, '/', 'a' );
                            fname_out = strrep( fname_out, '\', 'b' );
                            fname_out_w_dir = fullfile( directory_out, fname_out );
                            imwrite(background_crops{bj},fname_out_w_dir,'jpg');
                        end
                    end
                end
                
            end
        
        catch
            
            failed_files{end+1} = label_data(imi).fname_lb;
            
        end
        
        progress(imi,length(label_data));
        
    end
    
    if ~isempty(failed_files)
        disp('failed label files');
        disp(failed_files);
        
        crops(     isempty(crops)     ) = [];
        crop_desc( isempty(crop_desc) ) = [];
    end
    
end


function background_crops = generate_background_crops( im, box_in_r0rfc0cf, n)
    
    r0 = box_in_r0rfc0cf(1);
    rf = box_in_r0rfc0cf(2);
    c0 = box_in_r0rfc0cf(3);
    cf = box_in_r0rfc0cf(4);
    step_w = cf - c0 + 1;
    step_h = rf - r0 + 1;
    r0s = round(linspace(1, size(im,1)-step_h, 2*(size(im,1)/step_h)));
    c0s = round(linspace(1, size(im,2)-step_w, 2*(size(im,2)/step_w)));
    rfs = r0s + step_h;
    cfs = c0s + step_w;
    
    box_proposals_r0rfc0cf = [repmat([r0s' rfs'],length(c0s),1) sortrows(repmat([c0s' cfs'],length(r0s),1)) ];
    
    iou = intersection_over_union(box_in_r0rfc0cf,box_proposals_r0rfc0cf,'r0rfc0cf','r0rfc0cf');
    
    box_proposals_r0rfc0cf( iou > 0, : ) = [];
    
    selected_inds = randi(size(box_proposals_r0rfc0cf,1),1,n);
    
    box_proposals_r0rfc0cf = box_proposals_r0rfc0cf( selected_inds, : );
    
    background_crops = cell(1,n);
    for bi = 1:n
        r0 = box_proposals_r0rfc0cf(bi,1);
        rf = box_proposals_r0rfc0cf(bi,2);
        c0 = box_proposals_r0rfc0cf(bi,3);
        cf = box_proposals_r0rfc0cf(bi,4);
        background_crops{bi} = im( r0:rf, c0:cf, : );
    end
    
end



