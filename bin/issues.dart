import 'package:graphql/client.dart';
import 'package:dartdev_github_scripts/github_datatypes.dart';
import 'package:dartdev_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get showClosed => _results['closed'];
  bool get tsv => _results['tsv'];
  String get label => _results['label'];
  DateTime get from => DateTime.parse(_results.rest[0]);
  DateTime get to => DateTime.parse(_results.rest[1]);
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed', defaultsTo: false, abbr: 'c', negatable: false, help: 'show closed PRs in date range')
      ..addFlag('tsv', defaultsTo: false, abbr: 't', negatable: true, help: 'show results as TSV')
      ..addOption('label', defaultsTo: null, abbr: 'l', help: 'only issues with this label');
    try {
      _results = _parser.parse(args);
      if (_results['help'])  _printUsage();
      if (_results['closed'] && _results.rest.length != 2 ) throw('need start and end dates!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run issues.dart [--tsv] [--label label] [--closed fromDate toDate]');
    print('Prints issues in dart-lang/site-www repo.');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);

  var repos = ['site-www'];

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var state = GitHubIssueState.open;
  DateRange when = null;
  var rangeType = GitHubDateQueryType.none;
  if (opts.showClosed) {
    state = GitHubIssueState.closed;
    when = DateRange(DateRangeType.range, start: opts.from, end: opts.to);
    rangeType = GitHubDateQueryType.closed;
  }

  for(var repo in repos) {
    var issues = await github.fetch(owner: 'dart-lang', 
      name: repo, 
      type: GitHubIssueType.issue,
      state: state,
      dateQuery: rangeType,
      dateRange: when
    );
      
    var headerDelimiter = opts.tsv ? '' : '## ';
    print( opts.showClosed ? 
      "${headerDelimiter}Issues closed in dart-lang/${repo} from " + opts.from.toIso8601String() + ' to ' + opts.to.toIso8601String() :
      "${headerDelimiter}Open issues in dart-lang/${repo}");
    if (!opts.tsv) print('\n');

    print('There were ${issues.length} ' +
      ( opts.showClosed ? 'closed ' : ' open' ) + 'issues');
    if (!opts.tsv) print('\n');

    if (opts.tsv) print(Issue.tsvHeader);
    for(var issue in issues) {
      if (opts.label != null && !issue.labels.containsString(opts.label)) continue;
      var issueString = opts.tsv ? issue.toTsv() : issue.summary(linebreakAfter: true);
      print(issueString);
    }
  }
}
