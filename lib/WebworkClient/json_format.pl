# The json output format needs to collect the data differently than
# the other formats. It will return an array which alternates between
# key-names and values, and each relevant value will later undergo
# variable interpolation.

# Most parts which need variable interpolation end in "_VI".
# Other parts which need variable interpolation are:
#	hidden_input_field_*
#	real_webwork_*

@pairs_for_json = (
  "head_part001_VI", "<!DOCTYPE html>\n" . '<html $COURSE_LANG_AND_DIR>' . "\n"
);

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<head>
<meta charset='utf-8'>
<base href="TO_SET_LATER_SITE_URL">
<link rel="shortcut icon" href="/favicon.ico"/>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "head_part010", $nextBlock );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<!-- CSS Loads -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.13.2/themes/base/jquery-ui.min.css" integrity="sha512-ELV+xyi8IhEApPS/pSj66+Jiw+sOT1Mqkzlh8ExXihe4zfqbWkxPRi8wptXIO9g73FSlhmquFlUOuMSoXz5IRw==" crossorigin="anonymous" />
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.2.1/css/all.min.css" integrity="sha512-MV7K8+y+gLIBoVD59lQIYicR65iaqukzvf/nwasF0nqhPay5w/9lJmVM2hMDcnK1OnMGCdVK+iQrJ7lzPJQd1w==" crossorigin="anonymous" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css" integrity="sha512-SbiR/eusphKoMVVXysTKG/7VseWii+Y3FdHrt0EpKgpToZeemhqHeZeLWLhJutz/2ut2Vw1uQEj2MbRF+TVBUA==" crossorigin="anonymous">
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "head_part100", $nextBlock );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<!-- JS Loads -->
<script src="/Problem/mathjax-config.js" defer></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/3.2.2/es5/tex-chtml.min.js" defer integrity="sha512-T8xxpazDtODy3WOP/c6hvQI2O9UPdARlDWE0CvH1Cfqc0TXZF6GZcEKL7tIR8VbfS/7s/J6C+VOqrD6hIo++vQ==" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.3/jquery.min.js" integrity="sha512-STof4xm1wgkfm7heWqFJVn58Hm3EtS31XFaagaa8VMReCXAkQnJZ+jEy8PCC/iT18dFy95WcExNHFTqLyp72eQ==" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.13.2/jquery-ui.min.js" integrity="sha512-57oZ/vW8ANMjR/KQ6Be9v/+/h6bq9/l3f0Oc7vn6qMqyhvPd1cvKBRWWpzu0QoneImqr2SkmO4MSqU+RpHom3Q==" crossorigin="anonymous"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/js/bootstrap.bundle.min.js" defer integrity="sha512-i9cEfJwUwViEPFKdC1enz4ZRGBj8YQo6QByFTF92YXHi7waCqyexvRD75S5NVTsSiTv7rKWqG9Y5eFxmRsOn0A==" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/iframe-resizer/4.3.2/iframeResizer.contentWindow.min.js" integrity="sha512-14SY6teTzhrLWeL55Q4uCyxr6GQOxF3pEoMxo2mBxXwPRikdMtzKMYWy2B5Lqjr6PHHoGOxZgPaxUYKQrSmu0A==" crossorigin="anonymous"></script>

<script src="/Problem/problem.js" defer></script>
<script src="/Problem/submithelper.js" defer></script>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "head_part200", $nextBlock );

push( @pairs_for_json, "head_part300_VI", '$problemHeadText' . "\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<title>WeBWorK problem</title>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "head_part400", $nextBlock );

push( @pairs_for_json, "head_part999", "</head>\n" );

push( @pairs_for_json, "body_part001", "<body>\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<div class="container-fluid">
<div class="row-fluid">
<div class="span12 problem">
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part100", $nextBlock );

push( @pairs_for_json, "body_part300_VI", '$answerTemplate' . "\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<form id="problemMainForm" class="problem-main-form" name="problemMainForm" action="TO_SET_LATER_FORM_ACTION_URL" method="post">
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part500", $nextBlock );


$nextBlock = <<'ENDPROBLEMTEMPLATE';
<div id="problem_body" class="problem-content" $PROBLEM_LANG_AND_DIR>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part530_VI", $nextBlock );

push( @pairs_for_json, "body_part550_VI", '$problemText' . "\n" );

push( @pairs_for_json, "body_part590", "</div>\n" );

push( @pairs_for_json, "body_part650_VI", '$scoreSummary' . "\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<p>
<input type="submit" name="preview"  value="$STRING_Preview" />
<input type="submit" name="WWsubmit" value="$STRING_Submit"/>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part710_VI", $nextBlock );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<input type="submit" name="WWcorrectAns" value="$STRING_ShowCorrect"/>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part780_optional_VI", $nextBlock );

push( @pairs_for_json, "body_part790", "</p>\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
</form>
</div>
</div>
</div>
<div id="footer" lang="en" dir="ltr">
WeBWorK &copy; 1996-2019
</div>
</body>
</html>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part999", $nextBlock );

push( @pairs_for_json, "hidden_input_field_answersSubmitted", '1' );
push( @pairs_for_json, "hidden_input_field_sourceFilePath", '$sourceFilePath' );
push( @pairs_for_json, "hidden_input_field_problemSource", '$encoded_source' );
push( @pairs_for_json, "hidden_input_field_problemSeed", '$problemSeed' );
push( @pairs_for_json, "hidden_input_field_problemUUID", '$problemUUID' );
push( @pairs_for_json, "hidden_input_field_psvn", '$psvn' );
push( @pairs_for_json, "hidden_input_field_pathToProblemFile", '$fileName' );
push( @pairs_for_json, "hidden_input_field_courseName", '$courseID' );
push( @pairs_for_json, "hidden_input_field_courseID", '$courseID' );
push( @pairs_for_json, "hidden_input_field_userID", '$userID' );
push( @pairs_for_json, "hidden_input_field_course_password", '$course_password' );
push( @pairs_for_json, "hidden_input_field_displayMode", '$displayMode' );
push( @pairs_for_json, "hidden_input_field_outputFormat", 'json' );
push( @pairs_for_json, "hidden_input_field_language", '$formLanguage' );
push( @pairs_for_json, "hidden_input_field_showSummary", '$showSummary' );
push( @pairs_for_json, "hidden_input_field_forcePortNumber", '$forcePortNumber' );

# These are the real WeBWorK server URLs which the intermediate needs to use
# to communicate with WW, while the distant client must use URLs of the
# intermediate server (the man in the middle).

push( @pairs_for_json, "real_webwork_SITE_URL", '$SITE_URL' );
push( @pairs_for_json, "real_webwork_FORM_ACTION_URL", '$FORM_ACTION_URL' );
push( @pairs_for_json, "internal_problem_lang_and_dir", '$PROBLEM_LANG_AND_DIR');

# Output back to WebworkClient.pm is the reference to the array:
\@pairs_for_json;
