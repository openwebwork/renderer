$simple_format = <<'ENDPROBLEMTEMPLATE';
<!DOCTYPE html>
<html $COURSE_LANG_AND_DIR>
<head>
<meta charset='utf-8'>
<base href="$SITE_URL">
<link rel="shortcut icon" href="/favicon.ico"/>

<!-- CSS Loads -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.13.2/themes/base/jquery-ui.min.css" integrity="sha512-ELV+xyi8IhEApPS/pSj66+Jiw+sOT1Mqkzlh8ExXihe4zfqbWkxPRi8wptXIO9g73FSlhmquFlUOuMSoXz5IRw==" crossorigin="anonymous" />
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.2.1/css/all.min.css" integrity="sha512-MV7K8+y+gLIBoVD59lQIYicR65iaqukzvf/nwasF0nqhPay5w/9lJmVM2hMDcnK1OnMGCdVK+iQrJ7lzPJQd1w==" crossorigin="anonymous" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css" integrity="sha512-SbiR/eusphKoMVVXysTKG/7VseWii+Y3FdHrt0EpKgpToZeemhqHeZeLWLhJutz/2ut2Vw1uQEj2MbRF+TVBUA==" crossorigin="anonymous">

$extra_css_files

<!-- JS Loads -->
<script src="/Problem/mathjax-config.js" defer></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/3.2.2/es5/tex-chtml.min.js" defer integrity="sha512-T8xxpazDtODy3WOP/c6hvQI2O9UPdARlDWE0CvH1Cfqc0TXZF6GZcEKL7tIR8VbfS/7s/J6C+VOqrD6hIo++vQ==" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.3/jquery.min.js" integrity="sha512-STof4xm1wgkfm7heWqFJVn58Hm3EtS31XFaagaa8VMReCXAkQnJZ+jEy8PCC/iT18dFy95WcExNHFTqLyp72eQ==" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.13.2/jquery-ui.min.js" integrity="sha512-57oZ/vW8ANMjR/KQ6Be9v/+/h6bq9/l3f0Oc7vn6qMqyhvPd1cvKBRWWpzu0QoneImqr2SkmO4MSqU+RpHom3Q==" crossorigin="anonymous"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/js/bootstrap.bundle.min.js" defer integrity="sha512-i9cEfJwUwViEPFKdC1enz4ZRGBj8YQo6QByFTF92YXHi7waCqyexvRD75S5NVTsSiTv7rKWqG9Y5eFxmRsOn0A==" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/iframe-resizer/4.3.2/iframeResizer.contentWindow.min.js" integrity="sha512-14SY6teTzhrLWeL55Q4uCyxr6GQOxF3pEoMxo2mBxXwPRikdMtzKMYWy2B5Lqjr6PHHoGOxZgPaxUYKQrSmu0A==" crossorigin="anonymous"></script>

<script src="/Problem/problem.js" defer></script>
<script src="/Problem/submithelper.js" defer></script>

$extra_js_files

$problemHeadText
$problemPostHeaderText

<title>WeBWorK using host: $SITE_URL, format: simple seed: $problemSeed</title>
</head>
<body>
  <div class="container-fluid">
    <div class="row">
      <div class="col-12 problem">
        $answerTemplate
        <form id="problemMainForm" class="problem-main-form" name="problemMainForm" action="$FORM_ACTION_URL" method="post">
          <div id="problem_body" class="problem-content" $PROBLEM_LANG_AND_DIR>
            $problemText
          </div>
          $scoreSummary

          <input type="hidden" name="answersSubmitted" value="1">
          <input type="hidden" name="sourceFilePath" value = "$sourceFilePath">
          <input type="hidden" name="problemSourceURL" value = "$problemSourceURL">
          <input type="hidden" name="problemSource" value="$encoded_source">
          <input type="hidden" name="problemSeed" value = "$problemSeed">
          <input type="hidden" name="outputFormat" value="simple">
		  <input type="hidden" name="language" value="$formLanguage">
          <input type="hidden" name="showSummary" value="$showSummary">
          <p>
            <input type="submit" name="previewAnswers" class="btn btn-primary" value="$STRING_Preview" />
            <input type="submit" name="submitAnswers" class="btn btn-primary" value="$STRING_Submit"/>
            <input type="submit" name="showCorrectAnswers" class="btn btn-primary" value="$STRING_ShowCorrect"/>
          </p>
        </form>
      </div>
    </div>
  </div>
</body>
</html>

ENDPROBLEMTEMPLATE

$simple_format;
