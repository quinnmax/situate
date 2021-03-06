
function [] = labl_old_to_json( labl_fname )

    % [] = labl_old_to_json( labl_fname );
    % 
    % takes an old .labl text label and saves a .json label file to the existing directory
    
    label_data = situate.labl_load( labl_fname );

    label_data_trimmed = [];
    label_data_trimmed.labels       = label_data.labels_raw;
    label_data_trimmed.boxes_xywh   = label_data.boxes_xywh;
    label_data_trimmed.im_w         = label_data.im_w;
    label_data_trimmed.im_h         = label_data.im_h;

    restructured_data = [];
    restructured_data.im_w = label_data.im_w;
    restructured_data.im_h = label_data.im_h;
    objects = [];
    for oi = 1:length(label_data.labels_raw)
        if isempty(objects), objects.desc = label_data.labels_raw{oi}; 
        else objects(oi).desc = label_data.labels_raw{oi}; end
        objects(oi).box_xywh = label_data.boxes_xywh(oi,:);
        %obj_str = sprintf('object_%03d',oi);
        %restructured_data.(obj_str) = [];
        %restructured_data.(obj_str).desc = label_data.labels_raw{oi};
        %restructured_data.(obj_str).box_xywh = label_data.boxes_xywh(oi,:);
    end
    restructured_data.objects = objects;

    json_text = jsonencode( restructured_data );

    fname_out = [labl_fname(1:end-4) 'json'];
    fid = fopen( fname_out, 'w+' );
    fwrite( fid, json_text );
    fclose( fid );
    
end
