VIDEO_XML_PATH :: "video.xml";

#run {
    set_build_options_dc(.{do_output = false});

    generate();
}

generate :: () {
    at := current_time_monotonic();
    start_time := to_float64_seconds(at);

    source_string, ok := read_entire_file(VIDEO_XML_PATH);
    if !ok {
        log_error("video.xml not found");
    }

    root_node := parse_xml(source_string);

    xml_parse_time := to_float64_seconds(current_time_monotonic());
    log("Finished parsing video.xml in % seconds", xml_parse_time - start_time);

    loop(root_node);

    generation_time := to_float64_seconds(current_time_monotonic());
    log("Finished generation in        % seconds", generation_time - xml_parse_time);

    output();
    at = current_time_monotonic();
    end_time := to_float64_seconds(at);
    log("Finished writing to file in   % seconds", end_time - generation_time);
    log("Video binding generated in    % seconds", end_time - start_time);
}

Video_Constant :: struct {
    name  : string;
    type  : string;
    value : string;
}

Video_Struct_Member :: struct {
    name              : string;
    type              : string;
    bitmask           : int;
    array_prefix      : string;
    number_of_pointer : int;
    comment           : string;
}

Video_Struct :: struct {
    name: string;

}

video_constants : [..]Video_Constant;
video_structs   : [..]Video_Struct;


loop :: (root_node: Node) {
    for root_child: root_node.children {
        if root_child.tag_name == {
        case "types";
            handle_types(root_child);
        }
    }
}

output :: () {
    sb: String_Builder;
    append(*sb, VIDEO_OUTPUT_COMMON);
    output_constants(*sb);

    write_entire_file("video.jai", *sb);
}

handle_types :: (parent: Node) {
    for n : parent.children {
        category := get_attr(n, "category");
        if category == {
        case "define";
            handle_type_define(n);
        case "struct";
            handle_struct(n);
        }
    }
}

handle_type_define :: (parent: Node) {
    requires := get_attr(parent, "requires");

    if requires.count == 0 {
        return;
    }

    c : Video_Constant;

    for n : parent.children {
        if n.type == .NODE {
            if n.tag_name == "name" {
                c.name = n.inner_string;
            }
        } else {
            if begins_with(n.raw_string, "(") && ends_with(n.raw_string, ")") {
                c.value = sprint("#run VK_MAKE_VIDEO_STD_VERSION%", n.raw_string);
            }
        }
    }

    array_add(*video_constants, c);
}

handle_struct :: (parent: Node) {
    s : Video_Struct;

    for member_node : parent.children {
        m : Video_Struct_Member;
        if member_node.tag_name == {
        case "member";
            for member_child : member_node.children {
                if member_child.type == .NODE {
                    if member_child.tag_name == {
                    case "type";
                        m.type = convert_type(member_child.inner_string);
                    case "name";
                        m.name = member_child.inner_string;
                    case "enum";
                        m.array_prefix = sprint("[%]", member_child.inner_string);
                    case "comment";
                        m.comment = member_child.inner_string;
                    }
                } else {
                    s := trim(member_child.raw_string);

                    if begins_with(s, ":") {
                        s = remove_left(s, ":");
                        s = trim(s);
                        m.bitmask, ok = string_to_int(s);
                        assert(ok);
                    } else if begins_with(s, "[") && ends_with(s, "]") {
                        m.array_prefix = s;
                    } else if begins_with(s, "*") {
                        m.number_of_pointer = count_pointer(s);
                    }
                }
            }
        case "comment";
            m.comment = member_node.inner_string;
        }
    }

    array_add(*video_structs, s);
}

output_constants :: (sb: *String_Builder) {
    for c : video_constants {
        append(sb, c.name);
        if c.type.count > 0 {
            append(sb, " : ");
            append(sb, c.type);
            append(sb, " : ");
        } else {
            append(sb, " :: ");
        }

        append(sb, c.value);
        append(sb, ";\n");
    }
}

VIDEO_OUTPUT_COMMON :: #string DONE
VK_MAKE_VIDEO_STD_VERSION :: (major: u32, minor: u32, patch: u32) -> u32 {
    return (major << 22) | (minor << 12) | patch;
}

DONE

#import,file "xml_parser.jai";
#import "Basic";
#import "String";
#import "Compiler";
#import "File";
#load "generate_common.jai";
